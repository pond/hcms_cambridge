require "spec_helper.rb"

RSpec.describe "Redirections" do
  before :each do
    RedirectionsController.send(:remove_const, :BLOG_MAPPINGS)
    RedirectionsController.send(:remove_const, :PAGE_MAPPINGS)
    RedirectionsController.const_set(:BLOG_MAPPINGS, {})
    RedirectionsController.const_set(:PAGE_MAPPINGS, {})
  end

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

    it "checks articles too" do
      blog_page = create(:page, :blog)
      blog_page.revisions.first.update!(published: true)
      article = create(:article, page: blog_page, slug: blog_page.slug + "-unique-article-slug")
      article.revisions.first.update!(published: true)

      visit("/#{article.slug}")

      expect(page).to have_current_path(page_article_path(page_id: blog_page.slug, id: article.slug))
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

        visit("/pagelike-#{SecureRandom.uuid}")
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
        it "yields 404 and records no page impression with '#{ext}' (natural case)" do
          expect(PageImpression.count).to be_zero # (self-check)
          expect_any_instance_of(RedirectionsController).to receive(:show).at_least(:once).and_call_original

          visit("/#{@page.slug}#{ext}")

          expect(page.status_code).to eq(404)
          expect(PageImpression.count).to be_zero
        end

        it "yields 404 and records no page impression with '#{ext}' (upper case)" do
          expect(PageImpression.count).to be_zero # (self-check)
          expect_any_instance_of(RedirectionsController).to receive(:show).at_least(:once).and_call_original

          visit("/#{@page.slug}#{ext.upcase}")

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
      Hcms.config.statistics_ignore.each do | section, list |
        list.each do | item |
          random = SecureRandom.uuid
          case section
            when "match_exactly", :match_exactly
              test_positive = item
              test_negative = "#{item}#{random}"
            when "starts_with", :starts_with
              test_positive = "#{item}#{random}"
              test_negative = "#{random}#{item}#{random}"
            when "found_anywhere", :found_anywhere
              test_positive = "#{random}#{item}#{random}"
              test_negative = "#{random}#{item[...-1]}#{random}"
          end

          it "yields 404 and records no page impression when matching in '#{section}' with '#{item}' (natural case)" do
            expect(PageImpression.count).to be_zero # (self-check)
            expect_any_instance_of(RedirectionsController).to receive(:show).at_least(:once).and_call_original

            visit("/#{test_positive}.html")

            expect(page.status_code).to eq(404)
            expect(PageImpression.count).to be_zero
          end

          it "yields 404 and records no page impression when matching in '#{section}' with '#{item}' (upper case)" do
            expect(PageImpression.count).to be_zero # (self-check)
            expect_any_instance_of(RedirectionsController).to receive(:show).at_least(:once).and_call_original

            visit("/#{test_positive.upcase}.html")

            expect(page.status_code).to eq(404)
            expect(PageImpression.count).to be_zero
          end

          it "yields 404 and records no page impression without a match in '#{section}' with '#{item}'" do
            expect(PageImpression.count).to be_zero # (self-check)
            expect_any_instance_of(RedirectionsController).to receive(:show).at_least(:once).and_call_original

            visit("/#{test_negative}.html")

            expect(page.status_code).to eq(404)
            expect(PageImpression.count).to eql(1)
          end
        end
      end
    end
  end

  context "custom mappings" do
    Hcms.config.page_mappings.each do | match_path, mapped_page_slug |
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

  context "blog mappings" do
    Hcms.config.blog_mappings.each do | match_path, mapped_blog_page_slug |
      before :each do
        if Page.find_by_slug(mapped_blog_page_slug).nil?
          mapped_page = create(:page, :blog, slug: mapped_blog_page_slug)
          mapped_page.revisions.first.update!(published: true)
        end
      end

      it "redirects #{match_path} to the blog container" do
        blog = Page.find_by_slug(mapped_blog_page_slug)
        visit("/#{match_path}")

        expect(page).to have_current_path(page_path(blog.slug))
      end

      it "redirects #{match_path}/ to the blog container" do
        blog = Page.find_by_slug(mapped_blog_page_slug)
        visit("/#{match_path}/")

        expect(page).to have_current_path(page_path(blog.slug))
      end

      it "redirects #{match_path}/(maybe-others)/... to an article if one is found" do
        blog = Page.find_by_slug(mapped_blog_page_slug)

        article = create(:article, page: blog, slug: "foo-bar-baz")
        article.revisions.first.update!(published: true)

        visit("/#{match_path}/foo-bar-baz")
        expect(page).to have_current_path(page_article_path(page_id: blog.slug, id: "foo-bar-baz"))

        visit("/#{match_path}/2025/foo-bar-baz")
        expect(page).to have_current_path(page_article_path(page_id: blog.slug, id: "foo-bar-baz"))

        visit("/#{match_path}/2022/04/05/foo-bar-baz")
        expect(page).to have_current_path(page_article_path(page_id: blog.slug, id: "foo-bar-baz"))
      end

      it "redirects #{match_path}/(maybe-others)/... to the blog container if no article is found" do
        blog = Page.find_by_slug(mapped_blog_page_slug)

        visit("/#{match_path}/foo-bar-baz")
        expect(page).to have_current_path(page_path(blog.slug))

        visit("/#{match_path}/2025/foo-bar-baz")
        expect(page).to have_current_path(page_path(blog.slug))

        visit("/#{match_path}/2022/04/05/foo-bar-baz")
        expect(page).to have_current_path(page_path(blog.slug))
      end

      it "yields 404 if there is no blog page" do
        Page.destroy_all
        Article.destroy_all

        visit("/#{match_path}")

        expect(page.status_code).to eq(404)
      end
    end
  end
end
