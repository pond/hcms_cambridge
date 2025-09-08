require "spec_helper.rb"

RSpec.describe "Admin - statistics" do
  before :each do
    @page_1    = create(:page);                      @page_1.revisions.first.update!(published: true)
    @page_2    = create(:page, :blog, slug: 'blog'); @page_2.revisions.first.update!(published: true)
    @article_1 = create(:article, page: @page_2); @article_1.revisions.first.update!(published: true)
    @article_2 = create(:article, page: @page_2); @article_2.revisions.first.update!(published: true)
  end

  context "gathering", js: true do

    # One big test to save on spin-up time for headless Chrome.
    #
    it "records regular visits, redirection controller 302 and 404, ignores regular 404" do
      old_headers = page.driver.headers # (see 'ensure' block at the end)

      visit(page_path(@page_1.slug)) # Visit, normal page, no referrer
      expect(page).to have_text(@page_1.navigation_title)
      expect(page).to have_css("footer")

      visit(page_path(@page_2.slug)) # Visit blog, no referrer
      expect(page).to have_text(@page_2.navigation_title)
      expect(page).to have_css("footer")

      click_on(@article_1.title) # Visit article, blog page was the referrer
      expect(page).to have_text(spechelp_strip_markup @article_1.body)
      expect(page).to have_css("footer")

      expect(PageImpression.pluck(:path)).to eql(
        [page_path(@page_1.slug), page_path(@page_2.slug), page_article_path(@page_2.slug, @article_1.slug)]
      )

      expect(PageImpression.pluck(:controller)).to eql(
        ["pages", "pages", "articles"]
      )

      expect(PageImpression.pluck(:params)).to eql(
        [{"id" => @page_1.slug}, {"id" => @page_2.slug}, {"page_id" => @page_2.slug, "id" => @article_1.slug}]
      )

      server_host = Capybara.current_session.server.host
      server_port = Capybara.current_session.server.port
      base_url    = "http://#{server_host}:#{server_port}"

      expect(PageImpression.pluck(:referrer)).to eql(
        [nil, nil, base_url + page_path(@page_2.slug)]
      )

      PageImpression.delete_all

      # Hereafter, we'll process everything with a mock Referrer header.

      page.driver.headers = { "Referer" => "http://searchengine.example.com" }

      # Redirection controller 301

      test_path = "/blog/2020/#{@article_1.slug}"
      visit(test_path)

      expect(page).to have_text(spechelp_strip_markup @article_1.body)
      expect(page).to have_css("footer")
      expect(PageImpression.count).to eql(2) # Redirection plus article view, since there was a Referrer

      pi = PageImpression.first

      expect(pi.path      ).to eql(test_path)
      expect(pi.controller).to eql("redirections")
      expect(pi.action    ).to eql("show")
      expect(pi.status    ).to eql(301)

      PageImpression.delete_all

      # Redirection controller 404

      test_path = "/not-a-real-page/#{SecureRandom.uuid}"
      visit(test_path)

      expect(page.status_code).to eql(404)
      expect(PageImpression.count).to eql(1) # Redirect 404

      pi = PageImpression.first

      expect(pi.path      ).to eql(test_path)
      expect(pi.controller).to eql("redirections")
      expect(pi.action    ).to eql("show")
      expect(pi.status    ).to eql(404)

      PageImpression.delete_all

      # Does not record "regular" 404

      visit(page_path(SecureRandom.uuid))

      expect(page.status_code).to eql(404)
      expect(PageImpression.count).to be_zero

    ensure # Make sure any changes made above are reset
      page.driver.headers = old_headers
    end

    it "does not record if signed in (or the act of sigining in)" do
      spechelp_log_in()

      visit(page_path(@page_1.slug)) # Visit, normal page, no referrer
      expect(page).to have_text(@page_1.navigation_title)
      expect(page).to have_css("footer")

      # Two-for-one - visiting the login page does not create a record (the
      # after-action is skipped for that controller since it seems useless
      # to record such things) and the subsequent visit, proved by the prior
      # test to normally generate a record, was not recorded now that a user
      # is signed in.
      #
      expect(PageImpression.count).to be_zero
    end
  end # 'context "gathering", js: true do'

  context "navigation" do
    before :each do
      spechelp_log_in()
    end

    it "can be reached via main navigation" do
      visit(admin_pages_path())
      find(:css, "header").click_link("Statistics")

      expect(page).to have_current_path(admin_statistics_path())
      expect(find(:css, "section.main_content h1")).to have_text("Visitor statistics")
    end

    it "lists aggregations" do
      PageImpression.create!(
        path:       "/foo-150",
        controller: "testone",
        action:     "testtwo",
        params:     {"one" => 1, "controller" => "should_be_removed", "action" => "should_be_removed"},
        status:     150
      )

      [450, 500].each do | status |
        PageImpression.create!(
          path:       "/foo-450-and-500",
          controller: "testone",
          action:     "testtwo",
          params:     {},
          status:     status
        )
      end

      PageImpression.create!(
        path:       "/foo-401",
        controller: "testone",
        action:     "index",
        params:     {},
        status:     401
      )

      1.upto(3) do | index |
        PageImpression.create!(
          path:       page_path(@page_1.slug),
          controller: "pages",
          action:     "show",
          referrer:   index == 1 ? "Zebra" : "Aardvark",
          params:     {"id" => @page_1.slug},
          status:     200
        )
      end

      1.upto(2) do
        PageImpression.create!(
          path:       page_article_path(@page_2.slug, @article_2.slug),
          controller: "articles",
          action:     "show",
          params:     {"page_id" => @page_2.slug, "id" => @article_2.slug},
          status:     200
        )
      end

      visit(admin_statistics_path())

      # Expected sort by controller then path. Expect Article, Page, then the
      # nonsense Testone set.
      #
      table = find(:css, "section.main_content table tbody")

      expect(table.find_all(:css, "tr").size).to eql(5)
      expect(table.find(:css, "tr:nth-child(1)")).to have_text("Article - #{@article_2.title} #{page_article_path(@page_2.slug, @article_2.slug)} Yes 2 Show", exact: true)
      expect(table.find(:css, "tr:nth-child(2)")).to have_text("Page - #{@page_1.title} #{page_path(@page_1.slug)} Yes 3 Show", exact: true)
      expect(table.find(:css, "tr:nth-child(3)")).to have_text("Testone - testtwo /foo-150 Yes 1 Show", exact: true)
      expect(table.find(:css, "tr:nth-child(4)")).to have_text("Testone - list /foo-401 No 1 Show", exact: true)
      expect(table.find(:css, "tr:nth-child(5)")).to have_text("Testone - testtwo /foo-450-and-500 No 2 Show", exact: true)
    end

    it "shows details with simple success status and no referrer" do
      PageImpression.create!(
        path:       page_article_path(@page_2.slug, @article_2.slug),
        controller: "articles",
        action:     "show",
        params:     {"page_id" => @page_2.slug, "id" => @article_2.slug},
        status:     200
      )

      visit(admin_statistic_path(PageImpression.first))

      expect(find(:css, "section.main_content h1")).to have_text("Location “Article - #{@article_2.title}”")
      expect(find(:css, "section.main_content dl")).to have_text(PageImpression.first.path)
      expect(find(:css, "section.main_content dl")).to have_text("200 (yes)")
      expect(find(:css, "section.main_content dl")).to have_text("Referrals None recorded")
    end

    it "shows details with simple failure status" do
      PageImpression.create!(
        path:       "/foo-401",
        controller: "testone",
        action:     "edit",
        params:     {},
        status:     401
      )

      visit(admin_statistic_path(PageImpression.first))

      expect(find(:css, "section.main_content h1")).to have_text("Testone - edit")
      expect(find(:css, "section.main_content dl")).to have_text(PageImpression.first.path)
      expect(find(:css, "section.main_content dl")).to have_text("401 (no)")
      expect(find(:css, "section.main_content dl")).to have_text("Referrals None recorded")
    end

    it "shows details with mixed status" do
      [500, 450].each do | status |
        PageImpression.create!(
          path:       "/foo-450-and-500",
          controller: "testone",
          action:     "testtwo",
          params:     {},
          status:     status
        )
      end

      visit(admin_statistic_path(PageImpression.first))

      expect(find(:css, "section.main_content h1")).to have_text("Testone - testtwo")
      expect(find(:css, "section.main_content dl")).to have_text(PageImpression.first.path)
      expect(find(:css, "section.main_content dl")).to have_text("450, 500 (mixed)")
      expect(find(:css, "section.main_content dl")).to have_text("Referrals None recorded")
    end

    it "shows details with referrers sorted by highest count descending" do
      1.upto(3) do | index |
        PageImpression.create!(
          path:       page_path(@page_1.slug),
          controller: "pages",
          action:     "show",
          referrer:   index == 1 ? "Zebra" : "Aardvark",
          params:     {"id" => @page_1.slug},
          status:     200
        )
      end

      visit(admin_statistic_path(PageImpression.first))

      expect(find(:css, "section.main_content h1")).to have_text("Location “Page - #{@page_1.title}”")
      expect(find(:css, "section.main_content dl")).to have_text(PageImpression.first.path)
      expect(find(:css, "section.main_content dl")).to have_text("200 (yes)")
      expect(find(:css, "section.main_content dl")).to have_text("Referrals URL Number of referrals Aardvark 2 Zebra 1")
    end

    it "humanises a controller title" do
      PageImpression.create!(
        path:       "/page_impression/1",
        controller: "page_impressions",
        action:     "show",
        params:     {"id" => 1},
        status:     200
      )

      visit(admin_statistic_path(PageImpression.first))

      expect(find(:css, "section.main_content h1")).to have_text("Page impressions - show")
    end
  end # 'context "navigation" do'
end
