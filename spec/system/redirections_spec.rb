require "spec_helper.rb"

RSpec.describe "Redirections" do
  context "to a page" do
    it "redirects if found" do
      p = create(:page); p.revisions.first.update!(published: true)

      visit("/#{p.slug}")

      expect(page).to have_current_path(page_path(p.slug))
    end

    it "yields 404 if not found" do
      visit("/nothing")

      expect(page.status_code).to eq(404)
    end
  end

  context "to a blog container" do
    it "redirects to the first blog page by '/blog'" do
      page_1 = create(:page, :blog, created_at: Time.now - 1.year)
      page_1.revisions.first.update!(published: true)

      article_1 = create(:article, page: page_1)
      article_1.revisions.first.update!(published: true)

      page_2 = create(:page, :blog, created_at: Time.now)
      page_2.revisions.first.update!(published: true)

      article_2 = create(:article, page: page_2)
      article_2.revisions.first.update!(published: true)

      visit("/blog")

      expect(page).to have_current_path(page_path(page_1.slug())) # (the older page)
    end

    it "redirects to the first blog page by '/blog/'" do
      page_1 = create(:page, :blog, created_at: Time.now - 1.year)
      page_1.revisions.first.update!(published: true)

      article_1 = create(:article, page: page_1)
      article_1.revisions.first.update!(published: true)

      page_2 = create(:page, :blog, created_at: Time.now)
      page_2.revisions.first.update!(published: true)

      article_2 = create(:article, page: page_2)
      article_2.revisions.first.update!(published: true)

      visit("/blog/")

      expect(page).to have_current_path(page_path(page_1.slug())) # (the older page)
    end

    it "yields 404 if there is no blog page" do
      visit("/blog")

      expect(page.status_code).to eq(404)
    end
  end

  context "to a blog article" do
    it "redirects at '/blog/slug'" do
      p = create(:page, :blog)
      p.revisions.first.update!(published: true)

      article = create(:article, page: p)
      article.revisions.first.update!(published: true)

      visit "/blog/#{article.slug}"

      expect(page).to have_current_path(page_article_path(p.slug, article.slug))
    end

    it "redirects at '/blog/yyyy/mm/dd/slug'" do
      p = create(:page, :blog)
      p.revisions.first.update!(published: true)

      article = create(:article, page: p)
      article.revisions.first.update!(published: true)

      visit "/blog/2023/05/28/#{article.slug}"

      expect(page).to have_current_path(page_article_path(p.slug, article.slug))
    end

    it "yields 404 if no article is found" do
      p = create(:page, :blog)
      p.revisions.first.update!(published: true)

      visit "/blog/missing"

      expect(page.status_code).to eq(404)
    end
  end
end
