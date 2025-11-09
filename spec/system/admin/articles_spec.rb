require "spec_helper.rb"

RSpec.describe "Admin - articles" do
  include ApplicationHelper

  before :each do
    spechelp_log_in()

    @page = create(:page, :blog)
    @page.revisions.first.update!(published: true)
  end

  context "creation" do
    it "can create in a draft state " do
      visit(admin_pages_path())

      find(:css, "section.main_content table tbody tr:first-child").click_on("Articles")

      expect(find(:css, "section.main_content h1")).to have_text("Blog “#{@page.title}”")

      click_on("New blog article")

      title   = "Quick Brown Fox"
      summary = "Jumps Over The"
      body    = "<p>Lazy Dog</p>"

      fill_in("article_title",   with: title)
      fill_in("article_summary", with: summary)
      fill_in("article_body",    with: body)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("article_article_hero_image", image_path)

      click_on("Save draft")
      spechelp_check_flash(:notice, "New draft article created")

      expect(    Page.count).to eql(1)
      expect( Article.count).to eql(1)
      expect(Revision.count).to eql(2)

      expect(Article.first.title  ).to eql(title)
      expect(Article.first.slug   ).to eql(title.parameterize)
      expect(Article.first.summary).to eql(summary)
      expect(Article.first.body   ).to eql(body)

      expect(Article.first.revisions.size           ).to eql(1)
      expect(Article.first.revisions.first.current  ).to eql(true)
      expect(Article.first.revisions.first.published).to eql(false)

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Continue editing article draft", href: edit_admin_page_article_path(Page.first, Article.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("New blog article",               href: new_admin_page_article_path(Page.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("List articles",                  href: admin_page_articles_path(Page.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Page management",                href: admin_pages_path())

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing article draft")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      expect(page).to have_current_path(edit_admin_page_article_path(Page.first, Article.first))
      expect(page).to have_field("article_title", with: title)
    end

    it "can create in a published state" do
      visit(new_admin_page_article_path(@page))

      title   = "Quick Brown Fox"
      summary = "Jumps Over The"
      body    = "<p>Lazy Dog</p>"

      fill_in("article_title",   with: title)
      fill_in("article_summary", with: summary)
      fill_in("article_body",    with: body)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("article_article_hero_image", image_path)

      click_on("Publish article")
      spechelp_check_flash(:notice, "New article published")

      expect(    Page.count).to eql(1)
      expect( Article.count).to eql(1)
      expect(Revision.count).to eql(2)

      expect(Article.first.title  ).to eql(title)
      expect(Article.first.slug   ).to eql(title.parameterize)
      expect(Article.first.summary).to eql(summary)
      expect(Article.first.body   ).to eql(body)

      expect(Article.first.revisions.size           ).to eql(1)
      expect(Article.first.revisions.first.current  ).to eql(true)
      expect(Article.first.revisions.first.published).to eql(true)

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Edit article")

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit article")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      expect(page).to have_current_path(edit_admin_page_article_path(Page.first, Article.first))
      expect(page).to have_field("article_title", with: title)
    end

    it "validates" do
      visit(new_admin_page_article_path(@page))

      click_on("Publish article")

      expect(page).to have_css(".field_error_messages", text: "Title must be provided")
      expect(page).to have_css(".field_error_messages", text: "Thumbnail photo must be provided")
      expect(page).to have_css(".field_error_messages", text: "Brief summary must be provided")
      expect(page).to have_css(".field_error_messages", text: "Main article must be provided")
    end

    context "dynamic behaviour", js: true do
      it "Redactor text entry works" do
        visit(new_admin_page_article_path(@page))

        title   = "Quick Brown Fox"
        summary = "Jumps Over The"
        body    = "Lazy Dog"

        fill_in("article_title",   with: title)
        fill_in("article_summary", with: summary)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("article_article_hero_image", image_path)

        spechelp_fill_in_redactor(body, for_type: "article")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft article created")

        expect(    Page.count).to eql(1)
        expect( Article.count).to eql(1)
        expect(Revision.count).to eql(2)

        expect(Article.first.title  ).to eql(title)
        expect(Article.first.slug   ).to eql(title.parameterize)
        expect(Article.first.summary).to eql(summary)
        expect(Article.first.body   ).to eql("<p>#{body}</p>")

        expect(Article.first.revisions.size           ).to eql(1)
        expect(Article.first.revisions.first.current  ).to eql(true)
        expect(Article.first.revisions.first.published).to eql(false)
      end

      it "Redactor image uploads work" do
        visit(new_admin_page_article_path(@page))

        title   = "Quick Brown Fox"
        summary = "Jumps Over The"
        body    = "Lazy Dog"

        fill_in("article_title",   with: title)
        fill_in("article_summary", with: summary)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("article_article_hero_image", image_path)

        editor = find(:css, ".redactor_container .redactor-in")
        editor.click()

        find(:css, "#redactor_toolbar a.re-button.re-image").click()

        # See similar test in 'admin/pages_spec.rb' for commentary.
        #
        within(".redactor-modal-box") do
          expect(page).to have_css(".redactor-modal-header", text: "Image")
          expect(page).to have_css('input[name="file"][type="file"]', visible: false)

          image_path = Rails.root.join("spec", "fixtures", "example.jpg")
          find(".upload-redactor-box").click()
          attach_file("file", image_path, make_visible: true)
        end

        expect(page).to     have_field("article_body", visible: false, with: /\<figure/)
        expect(page).to_not have_css(".redactor-modal-box")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft article created")

        expect(Article.first.title  ).to eql(title)
        expect(Article.first.slug   ).to eql(title.parameterize)
        expect(Article.first.summary).to eql(summary)
        expect(Article.first.body   ).to include("<figure")
        expect(Article.first.body   ).to include("example.jpg")

        expect(Article.first.revisions.size           ).to eql(1)
        expect(Article.first.revisions.first.current  ).to eql(true)
        expect(Article.first.revisions.first.published).to eql(false)

        expect(Redactor3Rails::Asset.count                  ).to eql(1)
        expect(Redactor3Rails::Asset.first.data_file_name   ).to eql("example.jpg")
        expect(Redactor3Rails::Asset.first.data_content_type).to eql("image/jpeg")
      end

      it "Redactor file uploads work" do
        visit(new_admin_page_article_path(@page))

        title   = "Quick Brown Fox"
        summary = "Jumps Over The"
        body    = "Lazy Dog"

        fill_in("article_title",   with: title)
        fill_in("article_summary", with: summary)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("article_article_hero_image", image_path)

        editor = find(:css, ".redactor_container .redactor-in")
        editor.click()

        find(:css, "#redactor_toolbar a.re-button.re-file").click()

        within(".redactor-modal-box") do
          expect(page).to have_css(".redactor-modal-header", text: "File")
          expect(page).to have_css('input[name="file"][type="file"]', visible: false)

          file_path = Rails.root.join("spec", "fixtures", "example.pdf")

          find(".upload-redactor-box").click()
          attach_file("file", file_path, make_visible: true)
          fill_in("modal-file-title", with: "Example PDF file")
        end

        expect(page).to     have_field("article_body", visible: false, with: /example\.pdf/)
        expect(page).to_not have_css(".redactor-modal-box")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft article created")

        expect(Article.first.title  ).to eql(title)
        expect(Article.first.slug   ).to eql(title.parameterize)
        expect(Article.first.summary).to eql(summary)
        expect(Article.first.body   ).to include('/example.pdf" data-file="')
        expect(Article.first.body   ).to include(">Example PDF file</a>")

        expect(Article.first.revisions.size           ).to eql(1)
        expect(Article.first.revisions.first.current  ).to eql(true)
        expect(Article.first.revisions.first.published).to eql(false)

        expect(Redactor3Rails::Asset.count                  ).to eql(1)
        expect(Redactor3Rails::Asset.first.data_file_name   ).to eql("example.pdf")
        expect(Redactor3Rails::Asset.first.data_content_type).to eql("application/pdf")
      end
    end # 'context "dynamic behaviour", js: true do'
  end # 'context "creation" do'

  context "revision management" do
    context "with only one revision" do
      it "which is not published" do
        travel_to(Time.now) do
          article = create(:article, page: @page)

          visit(admin_page_article_path(@page, article))

          within "#publishing-info" do
            expect(page).to_not have_link("←")
            expect(page).to_not have_link("→")
            expect(page).to_not have_select("revision")
            expect(page).to     have_text("Draft (#{TimeZoneHelp.in_configured_time_zone(Time.now)})")
          end
        end
      end

      it "which is published" do
        article = create(:article, page: @page)
        article.revisions.first.update!(published: true)

        visit(admin_page_article_path(@page, article))

        within "#publishing-info" do
          expect(page).to_not have_link("←")
          expect(page).to_not have_link("→")
          expect(page).to_not have_select("revision")
          expect(page).to     have_text("Published")
        end
      end
    end # 'context "with only one revision" do'

    context "navigation with many revisions" do
      around :each do | example |
        travel_to(Time.now) do
          example.run()
        end
      end

      before :each do
        article = create(
          :article,
          page:      @page,
          revisions: [
            build(:revision, :for_article, created_at: Time.now - 4.days, current: false, published: false),
            build(:revision, :for_article, created_at: Time.now - 3.days, current: false, published: true ),
            build(:revision, :for_article, created_at: Time.now - 2.days, current: true,  published: false),
          ]
        )

        # Automated maintenance of 'current' will lead to updated-at changes
        # so we can't set that in the factories above.
        #
        Revision.for_articles.each { | revision | revision.update_column(:updated_at, revision.created_at) }

        visit(admin_page_article_path(@page, article))

        # Should default to the published revision - that's the second in the
        # ordered-by-creation-date set.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.second.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.summary)
      end

      def revision_options
        [
          "Old (#{TimeZoneHelp.in_configured_time_zone(Time.now - 4.days)})",
          "Published",
          "Draft (#{TimeZoneHelp.in_configured_time_zone(Time.now - 2.days)})",
        ]
      end

      it "navigation via the back/foward arrows" do
        within "#publishing-info" do
          expect(page).to have_button("←")
          expect(page).to have_button("→")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])

          click_on("←")
        end

        # Should now be on the oldest revision.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.third.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.third.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.third.summary)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          click_on("→")
        end

        # Returned to the published one.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.second.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.summary)

        within "#publishing-info" do
          expect(page).to have_button("→")
          expect(page).to have_button("←")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])

          click_on("→")
        end

        # Now showing the newest, a current draft.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.first.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.first.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.first.summary)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          click_on("←")
        end

        # Returned to the published one.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.second.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.summary)

        within "#publishing-info" do
          expect(page).to have_button("←")
          expect(page).to have_button("→")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])
        end
      end

      it "navigation via the menu", js: true do
        within "#publishing-info" do
          expect(page).to have_button("←")
          expect(page).to have_button("→")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])

          select(revision_options()[0], from: "revision")
        end

        # Should now be on the oldest revision.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.third.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.third.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.third.summary)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          select(revision_options()[2], from: "revision")
        end

        # Now showing the newest, a current draft.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.first.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.first.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.first.summary)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          select(revision_options()[1], from: "revision")
        end

        # Returned to the published one.
        #
        displayed_article = find(:css, "section.main_content article")
        expect(displayed_article).to have_text(spechelp_strip_markup Revision.for_articles.second.body)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.title)
        expect(displayed_article).to have_text(                      Revision.for_articles.second.summary)

        within "#publishing-info" do
          expect(page).to have_button("←")
          expect(page).to have_button("→")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])
        end
      end
    end # 'context "navigation with many revisions" do'

    it "can roll back and edit, creating a new draft after a published revision" do
      visit(new_admin_page_article_path(@page))

      title   = "Quick Brown Fox"
      summary = "Jumps Over The"
      body    = "<p>Lazy Dog</p>"

      fill_in("article_title",   with: title)
      fill_in("article_summary", with: summary)
      fill_in("article_body",    with: body)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("article_article_hero_image", image_path)

      click_on("Publish article")
      spechelp_check_flash(:notice, "New article published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit article")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      fill_in("article_title", with: title + " 2")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Article changes published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(2)

      expect(Revision.for_articles.pluck(:published)).to eql([true, false])
      expect(Revision.for_articles.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit using this article revision")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      expect(page).to have_field("article_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("article_title", with: title + " 3")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Article changes published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(3)

      expect(Revision.for_articles.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.for_articles.pluck(:published)).to eql([true, false, false])
      expect(Revision.for_articles.pluck(:current  )).to eql([true, false, false])
    end

    # Copy-paste of the above test, but note the second edit is saved as a
    # draft rather than published.
    #
    it "can roll back and edit, creating a new draft after a now-abandoned prior current draft revision" do
      visit(new_admin_page_article_path(@page))

      title   = "Quick Brown Fox"
      summary = "Jumps Over The"
      body    = "<p>Lazy Dog</p>"

      fill_in("article_title",   with: title)
      fill_in("article_summary", with: summary)
      fill_in("article_body",    with: body)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("article_article_hero_image", image_path)

      click_on("Publish article")
      spechelp_check_flash(:notice, "New article published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit article")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      fill_in("article_title", with: title + " 2")

      # This is where this test starts to differ from the previous test.
      #
      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(2)

      # Note that we've now still got an older published draft and a new,
      # current draft; but we're going to step back and edit the published
      # original. The current draft should now end up a non-current abandoned
      # draft, with our edits appearing in a newest, third revision.
      #
      expect(Revision.for_articles.pluck(:published)).to eql([false, true])
      expect(Revision.for_articles.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit article, ignoring current draft")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      expect(page).to have_field("article_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("article_title", with: title + " 3")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Article changes published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(3)

      expect(Revision.for_articles.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.for_articles.pluck(:published)).to eql([true, false, false])
      expect(Revision.for_articles.pluck(:current  )).to eql([true, false, false])
    end

    # This test starts much like the one above, up until stepping back to the
    # published revision after saving a draft. Then, though, it steps forward
    # and makes sure it can edit that still-current draft.
    #
    it "can 'roll back and forward again' and edit the current draft revision" do
      visit(new_admin_page_article_path(@page))

      title   = "Quick Brown Fox"
      summary = "Jumps Over The"
      body    = "<p>Lazy Dog</p>"

      fill_in("article_title",   with: title)
      fill_in("article_summary", with: summary)
      fill_in("article_body",    with: body)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("article_article_hero_image", image_path)

      click_on("Publish article")
      spechelp_check_flash(:notice, "New article published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit article")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      fill_in("article_title", with: title + " 2")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(2)

      expect(Revision.for_articles.pluck(:published)).to eql([false, true])
      expect(Revision.for_articles.pluck(:current  )).to eql([true, false])

      # This works because we're using the Rack driver - synchronous, no wait
      # states / race conditions.
      #
      within "#publishing-info" do
        click_on("←")
      end

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Edit")

      within "#publishing-info" do
        click_on("→")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing article draft")
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      expect(page).to have_field("article_title", with: title + " 2")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Article changes published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(2)

      expect(Revision.for_articles.pluck(:published)).to eql([true, false])
      expect(Revision.for_articles.pluck(:current  )).to eql([true, false])
    end
  end # 'context "revision management" do'

  context "raw editor" do
    it "can be selected when creating a draft" do
      visit(new_admin_page_article_path(@page))

      title   = "Quick Brown Fox"
      summary = "Jumps Over The"
      body    = "<p>Lazy Dog</p>"

      fill_in("article_title",   with: title)
      fill_in("article_summary", with: summary)
      fill_in("article_body",    with: body)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("article_article_hero_image", image_path)

      check("article_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1)

      expect(Article.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_article_path(@page, Article.first))
      expect(page).to have_css("textarea#article_body")
      expect(page).to have_field("article_body", with: body)

      fill_in("article_body", with: body + "<p>!</p>")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Article changes published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1)

      expect(Article.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when creating a new published page" do
      visit(new_admin_page_article_path(@page))

      title   = "Quick Brown Fox"
      summary = "Jumps Over The"
      body    = "<p>Lazy Dog</p>"

      fill_in("article_title",   with: title)
      fill_in("article_summary", with: summary)
      fill_in("article_body",    with: body)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("article_article_hero_image", image_path)

      check("article_raw_editor")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1)

      expect(Article.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_article_path(@page, Article.first))
      expect(page).to have_css("textarea#article_body")
      expect(page).to have_field("article_body", with: body)

      fill_in("article_body", with: body + "<p>!</p>")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Article changes published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(2) # (we edited a published article, so there's a new revision)

      expect(Article.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when saving an edit of an existing page as a draft" do
      article = create(:article, page: @page)

      expect(article.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_page_article_path(@page, article))
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      check("article_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1) # (existing draft was altered)

      expect(article.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_article_path(@page, article))
      expect(page).to have_css("textarea#article_body")
      expect(page).to have_field("article_body", with: article.body)
    end

    it "can be selected when publishing an edit of an existing page" do
      article = create(:article, page: @page)

      expect(article.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_page_article_path(@page, article))
      find(:css, "details > summary", text: "Expand to edit article attributes").click()

      check("article_raw_editor")

      click_on("Publish article")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(              Article.count).to eql(1)
      expect(Revision.for_articles.count).to eql(1) # (existing draft was altered)

      expect(article.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_article_path(@page, article))
      expect(page).to have_css("textarea#article_body")
      expect(page).to have_field("article_body", with: article.body)
    end
  end # 'context "raw editor" do'

  context "lists" do
    context "display" do
      it "shows details" do
        article_1 = create(:article, page: @page, created_at: Time.now - 5.seconds) # Draft
        article_2 = create(:article, page: @page, created_at: Time.now - 4.seconds); article_2.revisions.first.update!(published: true)
        article_3 = create(:article, page: @page, created_at: Time.now - 3.seconds); article_3.revisions.first.update!(published: true)

        article_3.revisions << build(:revision, :for_article)
        article_3.save!

        visit(admin_page_articles_path(@page))

        expect(find(:css, "section.main_content h1")).to have_text("Blog “#{@page.title}”")

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")

        # Title / Published? / Draft? / In menu? / Actions
        #
        # Note reverse order - created-at DESC sorting.
        #
        expect(row_1).to have_text("#{article_3.title} #{apphelp_human_time(article_3.created_at, date_only: true)} Yes Yes Show Edit Delete", exact: true)
        expect(row_2).to have_text("#{article_2.title} #{apphelp_human_time(article_2.created_at, date_only: true)} Yes No Show Edit Delete", exact: true)
        expect(row_3).to have_text("#{article_1.title} #{apphelp_human_time(article_1.created_at, date_only: true)} No Yes Show Edit Delete", exact: true)

        # Check a few links. Column 1 - article title, 2 - published date,
        # 3-4 - boolean, 5 - main actions, 6 - delete action.
        #
        expect(row_1.find(:css, "> td:nth-child(4)")).to have_link("Yes", href: admin_page_article_path(@page, article_3, revision: article_3.revisions.last.id))
        expect(row_2.find(:css, "> td:nth-child(5)")).to have_link("Show", href: admin_page_article_path(page_id: @page.slug, id: article_2.slug))
        expect(row_3.find(:css, "> td:nth-child(5)")).to have_link("Edit", href: edit_admin_page_article_path(page_id: @page.id, id: article_1.id))
      end

      it "links to the blog page" do
        visit(admin_page_articles_path(@page))

        expect(page).to have_link("View article grid", href: admin_page_path(@page.slug))
      end

      it "links to the main 'all pages' list" do
        visit(admin_page_articles_path(@page))

        expect(page).to have_link('Back to "All pages" list', href: admin_pages_path())
      end
    end # 'context "display" do'

    context "actions" do
      it "deletes with confirmation", js: true do
        article = create(:article, page: @page)

        expect(Revision.count).to eql(2) # (self-check)

        visit(admin_page_articles_path(@page))

        accept_confirm do
          find(:css, "table tbody tr td:last-child").click_link("Delete")
        end

        spechelp_check_flash(:notice, "Article deleted")

        expect(Article.exists?(article.id)).to eql(false)

        expect(Revision.count).to eql(1)
      end
    end # 'context "actions" do'
  end # 'context "lists" do'"
end
