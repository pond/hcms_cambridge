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

    context "with a referrer header set" do
      before :each do
        page.driver.header("Referer", "http://searchengine.example.com")
      end

      it "yields 404 and records no page impressions with non-HTML requests" do
        expect(PageImpression.count).to be_zero # (self-check)
        expect_any_instance_of(RedirectionsController).to_not receive(:show)

        visit("/#{@page.slug}.png")
        expect(page.status_code).to eq(404)

        visit("/#{@page.slug}.xml")
        expect(page.status_code).to eq(404)

        visit("/#{@page.slug}.txt")
        expect(page.status_code).to eq(404)

        visit("/#{@page.slug}.js")
        expect(page.status_code).to eq(404)

        expect(PageImpression.count).to be_zero
      end

      it "yields 404 and records a page impression with other requests if not found" do
        expect(PageImpression.count).to be_zero # (self-check)
        expect_any_instance_of(RedirectionsController).to receive(:show).and_call_original

        visit("/missing-missing")
        expect(page.status_code).to eq(404)

        expect(PageImpression.count).to eql(1)
      end
    end

    # RESTORE THIS if you elect to include "request.referrer.blank?" as a check
    # in RedirectionsController#no_page_impression?
    #
    # context "without a referrer header set" do
    #   before :each do
    #     page.driver.header("Referer", nil)
    #   end
    #
    #   it "yields 404, but records no page impression" do
    #     expect(PageImpression.count).to be_zero # (self-check)
    #     expect_any_instance_of(RedirectionsController).to receive(:show).and_call_original
    #
    #     visit("/missing-missing")
    #     expect(page.status_code).to eq(404)
    #
    #     expect(PageImpression.count).to be_zero
    #   end
    # end

    context "'ignore' extensions" do
      RedirectionsController::IGNORE_EXTENSIONS.each do | ext |
        it "yields 404 and records no page impression with '#{ext}'" do
          expect(PageImpression.count).to be_zero # (self-check)
          expect_any_instance_of(RedirectionsController).to receive(:show).at_least(:once).and_call_original

          visit("/#{@page.slug}#{ext}")

          expect(page.status_code).to eq(404)
          expect(PageImpression.count).to be_zero
        end
      end

      it "yields 404 and records no page impression paths starting '.'" do
        expect(PageImpression.count).to be_zero # (self-check)

        visit("/.env")
        expect(page.status_code).to eq(404)

        visit("/.foo")
        expect(page.status_code).to eq(404)

        visit("/.ssh/hackery")
        expect(page.status_code).to eq(404)

        expect(PageImpression.count).to be_zero
      end
    end

    context "ignore paths" do
      it "yields 404 and records no page impression with certain paths" do
        expect(PageImpression.count).to be_zero # (self-check)
        expect_any_instance_of(RedirectionsController).to receive(:show).at_least(:once).and_call_original

        visit("/wp-#{@page.slug}.html")

        expect(page.status_code).to eq(404)
        expect(PageImpression.count).to be_zero
      end
    end
  end

  context "custom mappings" do
    RedirectionsController::CUSTOM_MAPPINGS.each do | match_path, mapped_page_slug |
      before :each do
        if Page.find_by_slug(mapped_page_slug).nil?
          mapped_page = create(:page, slug: mapped_page_slug)
          mapped_page.revisions.first.update!(published: true)
        end
      end

      it "redirects #{match_path}" do
        visit("/#{match_path}")

        expect(page).to have_current_path(page_path(Page.find_by_slug(mapped_page_slug).slug))
      end

      it "redirects #{match_path}/" do
        visit("/#{match_path}/")

        expect(page).to have_current_path(page_path(Page.find_by_slug(mapped_page_slug).slug))
      end

      it "redirects #{match_path}/..." do
        visit("/#{match_path}/foo-bar-baz")

        expect(page).to have_current_path(page_path(Page.find_by_slug(mapped_page_slug).slug))
      end
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

      expect(page).to have_current_path(page_path(@page.slug))
    end

    it "redirects to the first blog page by '/blog/'" do
      visit("/blog/")

      expect(page).to have_current_path(page_path(@page.slug))
    end

    it "redirects to the first blog page by '/blog.htm'" do
      visit("/blog.htm")

      expect(page).to have_current_path(page_path(@page.slug))
    end

    it "redirects to the first blog page by '/blog.htm'" do
      visit("/blog.html")

      expect(page).to have_current_path(page_path(@page.slug))
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
