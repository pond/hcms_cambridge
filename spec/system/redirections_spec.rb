require "spec_helper.rb"

RSpec.describe "Redirections" do
  context "to a page" do
    before :each do
      @page = create(:page)
      @page.revisions.first.update!(published: true)
    end

    it "redirects if found" do
      visit("/#{@page.slug}")

      expect(page).to have_current_path(page_path(@page.slug))
    end

    it "redirects if found (with '.htm' extension)" do
      visit("/#{@page.slug}.htm")

      expect(page).to have_current_path(page_path(@page.slug))
    end

    it "redirects if found (with '.html' extension)" do
      visit("/#{@page.slug}.html")

      expect(page).to have_current_path(page_path(@page.slug))
    end

    it "yields 404 with other extensions" do
      visit("/#{@page.slug}.png")
      expect(page.status_code).to eq(404)

      visit("/#{@page.slug}.xml")
      expect(page.status_code).to eq(404)

      visit("/#{@page.slug}.txt")
      expect(page.status_code).to eq(404)

      visit("/#{@page.slug}.js")
      expect(page.status_code).to eq(404)
    end

    it "yields 404 if not found" do
      visit("/missing-missing")

      expect(page.status_code).to eq(404)
    end
  end

  context "to a blog container" do
    before :each do
      page_1 = create(:page, :blog, created_at: Time.now - 1.year)
      page_1.revisions.first.update!(published: true)

      article_1 = create(:article, page: page_1)
      article_1.revisions.first.update!(published: true)

      page_2 = create(:page, :blog, created_at: Time.now)
      page_2.revisions.first.update!(published: true)

      article_2 = create(:article, page: page_2)
      article_2.revisions.first.update!(published: true)

      @page = page_1 # (the older page)
    end

    it "redirects to the first blog page by '/blog'" do
      visit("/blog")

      expect(page).to have_current_path(page_path(@page.slug()))
    end

    it "redirects to the first blog page by '/blog/'" do
      visit("/blog/")

      expect(page).to have_current_path(page_path(@page.slug()))
    end

    it "redirects to the first blog page by '/blog.htm'" do
      visit("/blog.htm")

      expect(page).to have_current_path(page_path(@page.slug()))
    end

    it "redirects to the first blog page by '/blog.htm'" do
      visit("/blog.html")

      expect(page).to have_current_path(page_path(@page.slug()))
    end

    it "yields 404 if there is no blog page" do
      Page.destroy_all
      Article.destroy_all

      visit("/blog")

      expect(page.status_code).to eq(404)
    end
  end

  context "to a blog article" do
    before :each do
      @page = create(:page, :blog)
      @page.revisions.first.update!(published: true)

      @article = create(:article, page: @page)
      @article.revisions.first.update!(published: true)
    end

    it "redirects at '/blog/slug'" do
      visit "/blog/#{@article.slug}"

      expect(page).to have_current_path(page_article_path(@page.slug, @article.slug))
    end

    it "redirects at '/blog/yyyy/mm/dd/slug'" do
      visit "/blog/2023/05/28/#{@article.slug}"

      expect(page).to have_current_path(page_article_path(@page.slug, @article.slug))
    end

    it "yields 404 if no article is found" do
      visit "/blog/missing-missing"

      expect(page.status_code).to eq(404)
    end
  end
end
