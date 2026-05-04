require "spec_helper.rb"
require_relative "shared_examples/footer.rb"

RSpec.describe "Pages" do
  before :each do
    @page = create(:page, :blog)
    @page.revisions.first.update!(published: true)
  end

  it "lists in created-at descending order and links to the articles" do
    p         = create(:page, :blog); p.revisions.first.update!(published: true) # ...so it'll be in the menu bar
    article_1 = create(:article, page: p, created_at: Time.now + 1.day); article_1.revisions.first.update!(published: true) # NOTE: Newer
    article_2 = create(:article, page: p, created_at: Time.now - 1.day); article_2.revisions.first.update!(published: true) # NOTE: Older

    visit page_path(p)

    expect(find(:css, "section.blog-articles article:nth-child(1)")).to have_text(article_1.title)
    expect(find(:css, "section.blog-articles article:nth-child(2)")).to have_text(article_2.title)

    # Blog main page is highlighted as current item in navigation.
    #
    expect(find(:css, "nav.main_menu li.current")).to have_link(p.title)

    find(:css, "section.blog-articles article:nth-child(1)").click_on(article_1.title)

    expect(page).to have_current_path(page_article_path(page_id: p.slug, id: article_1.slug))

    # Title, summary and body but no hero image in the main article.
    #
    expect(page).to     have_text(article_1.title)
    expect(page).to     have_text(article_1.summary)
    expect(page).to     have_text(spechelp_strip_markup article_1.body)
    expect(page).to_not have_css("img.article-hero-image[alt=\"#{article_1.title}\"]")

    # Blog main page is still highlighted as current item in navigation.
    #
    expect(find(:css, "nav.main_menu li.current")).to have_link(p.title)
  end

  it "does not show drafts" do
    p         = create(:page, :blog)
    article_1 = create(:article, page: p) # Note, not published
    article_2 = create(:article, page: p) # Same

    visit page_path(p)

    expect(page).to     have_text("No articles have been written")
    expect(page).to_not have_text(article_1.title)
    expect(page).to_not have_text(article_2.title)

    article_1.revisions.first.update!(published: true)
    article_2.revisions.first.update!(published: true)

    article_2_published_revision = article_2.revisions.first
    article_2_draft_revision     = build(:revision, :for_article) # Draft, shouldn't show up
    article_2.revisions << article_2_draft_revision
    article_2.save!

    visit page_path(p)

    expect(page).to_not have_text("No articles have been written")

    expect(page).to     have_text(article_1.title)
    expect(page).to     have_text(article_1.summary)
    expect(page).to_not have_text(spechelp_strip_markup article_1.body)
    expect(page).to     have_css("img.article-hero-image[alt=\"#{article_1.title}\"]")

    expect(page).to     have_text(article_2_published_revision.title)
    expect(page).to     have_text(article_2_published_revision.summary)
    expect(page).to_not have_text(spechelp_strip_markup article_2.body)
    expect(page).to     have_css("img.article-hero-image[alt=\"#{article_2_published_revision.title}\"]")

    expect(page).to_not have_text(article_2_draft_revision.title)
    expect(page).to_not have_text(article_2_draft_revision.summary)
    expect(page).to_not have_css("img.article-hero-image[alt=\"#{article_2_draft_revision.title}\"]")
  end

  context "navigation" do
    it "redirects to the Admin page if logged in" do
      p = create(:page, :blog)
      p.revisions.first.update!(published: true)

      article = create(:article, page: p)
      article.revisions.first.update!(published: true)

      visit(page_path(p.slug))
      expect(page).to have_current_path(page_path(p.slug)) # No redirection

      visit(page_article_path(p.slug, article.slug))
      expect(page).to have_current_path(page_article_path(p.slug, article.slug)) # No redirection

      spechelp_log_in()

      visit(page_path(p.slug))
      expect(page).to have_current_path(admin_page_path(p.slug)) # Redirected to admin

      visit(page_article_path(p.slug, article.slug))
      expect(page).to have_current_path(admin_page_article_path(p.slug, article.slug)) # Redirected to admin
    end

    it "offers older/newer links where relevant" do
      p = create(:page, :blog)
      p.revisions.first.update!(published: true)

      article_1 = create(:article, page: p, created_at: Time.now - 2.weeks)
      article_1.revisions.first.update!(published: true)

      # No links when there's only one article

      visit(page_article_path(p.slug, article_1.slug))

      expect(page).to_not have_css("a[rel='older']")
      expect(page).to_not have_css("a[rel='newer']")

      # Use a total of three articles to test older/newer appearing or
      # disappearing at each end of the chain

      article_2 = create(:article, page: p, created_at: Time.now - 1.week)
      article_2.revisions.first.update!(published: true)

      article_3 = create(:article, page: p, created_at: Time.now)
      article_3.revisions.first.update!(published: true)

      visit(page_article_path(p.slug, article_3.slug))

      expect(page).to     have_css("a[rel='older'][href='#{page_article_path(page_id: p.slug, id: article_2.slug)}']")
      expect(page).to_not have_css("a[rel='newer']")

      visit(page_article_path(p.slug, article_2.slug))

      expect(page).to have_css("a[rel='older'][href='#{page_article_path(page_id: p.slug, id: article_1.slug)}']")
      expect(page).to have_css("a[rel='newer'][href='#{page_article_path(page_id: p.slug, id: article_3.slug)}']")

      visit(page_article_path(p.slug, article_1.slug))

      expect(page).to_not have_css("a[rel='older']")
      expect(page).to     have_css("a[rel='newer'][href='#{page_article_path(page_id: p.slug, id: article_2.slug)}']")

      # Add a fourth, oldest article but in a new page. This should not appear
      # in the other page's set of links (or vice versa).

      p_other = create(:page, :blog)
      p_other.revisions.first.update!(published: true)

      article_4 = create(:article, page: p_other, created_at: Time.now - 3.weeks)
      article_4.revisions.first.update!(published: true)

      visit(page_article_path(p_other.slug, article_4.slug))

      expect(page).to_not have_css("a[rel='older']")
      expect(page).to_not have_css("a[rel='newer']")

      visit(page_article_path(p.slug, article_1.slug))

      expect(page).to_not have_css("a[rel='older']")
    end
  end # 'context "navigation" do'

  context "shared" do
    let(:path_to_test) { root_path() }

    before :each do
      @article = create(:article, page: @page)
      @article.revisions.first.update!(published: true)
    end

    context "when viewing the blog container" do
      let(:path_to_test) { page_path(@page.slug) }
      it_behaves_like "a public page footer"
    end

    context "when viewing an article" do
      let(:path_to_test) { page_article_path(@page.slug, @article.slug) }
      it_behaves_like "a public page footer"
    end
  end # 'context "shared" do'
end
