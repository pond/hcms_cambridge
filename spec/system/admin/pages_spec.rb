require "spec_helper.rb"

RSpec.describe "Admin - pages" do
  before :each do
    allow(Rails.application.config.uk_org_pond_hcms).to receive(:booking_hide_date).and_return(false)
    spechelp_log_in()
  end

  context "creation" do
    it "can create in a draft state " do
      visit(admin_pages_path())
      click_on("New page")

      title            = "Quick Brown Fox"
      navigation_title = "Jumps Over The"
      body             = "<p>Lazy Dog</p>"

      fill_in("page_title",            with: title)
      fill_in("page_navigation_title", with: navigation_title)
      fill_in("page_body",             with: body)

      click_on("Save draft")
      spechelp_check_flash(:notice, "New draft page created")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1)

      expect(Page.first.title           ).to eql(title)
      expect(Page.first.slug            ).to eql(title.parameterize)
      expect(Page.first.navigation_title).to eql(navigation_title)
      expect(Page.first.body            ).to eql(body)

      expect(Page.first.revisions    ).to match_array(Revision.all)
      expect(Revision.first.current  ).to eql(true)
      expect(Revision.first.published).to eql(false)

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Continue editing draft", href: edit_admin_page_path(Page.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("New page",               href: new_admin_page_path())
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("All pages",              href: admin_pages_path())

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing draft")

      expect(page).to have_current_path(edit_admin_page_path(Page.first.id))
      expect(page).to have_field("page_title", with: title)
    end

    it "can create in a published state" do
      visit(new_admin_page_path())

      title            = "Quick Brown Fox"
      navigation_title = "Jumps Over The"
      body             = "<p>Lazy Dog</p>"

      fill_in("page_title",            with: title)
      fill_in("page_navigation_title", with: navigation_title)
      fill_in("page_body",             with: body)

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1)

      expect(Page.first.title           ).to eql(title)
      expect(Page.first.slug            ).to eql(title.parameterize)
      expect(Page.first.navigation_title).to eql(navigation_title)
      expect(Page.first.body            ).to eql(body)

      expect(Page.first.revisions    ).to match_array(Revision.all)
      expect(Revision.first.current  ).to eql(true)
      expect(Revision.first.published).to eql(true)

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Edit")

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit")

      expect(page).to have_current_path(edit_admin_page_path(Page.first.id))
      expect(page).to have_field("page_title", with: title)
    end

    it "validates" do
      visit(new_admin_page_path())

      click_on("Publish page")

      expect(page).to have_css(".field_error_messages", text: "Page title must be provided")
      expect(page).to have_css(".field_error_messages", text: "Main page text must be provided")

      fill_in("page_title", with: "Quick Brown Fox")
      fill_in("page_slug",  with: "qbf")
      fill_in("page_body",  with: "<p>Lazy Dog</p>")

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      visit(new_admin_page_path())

      fill_in("page_title", with: "Another Quick Brown Fox")
      fill_in("page_slug",  with: "qbf") # Note duplicated, but explicitly given slug
      fill_in("page_body",  with: "<p>Another Lazy Dog</p>")

      click_on("Publish page")

      expect(page).to have_css(".field_error_messages", text: "Path / 'slug' has already been taken")
    end

    context "parent-child" do
      it "offers no parent selector when there are no pages created yet" do
        visit(new_admin_page_path())

        expect(page).to     have_css(".redactor_container")
        expect(page).to_not have_field("page_page_id")
      end

      it "offers a parent selector when there are top-level parents, hidden or otherwise" do
        page_1 = create(:page, hidden: true  ); page_1.revisions.first.update!(published: true)
        page_2 = create(:page                )
        page_3 = create(:page                ); page_3.revisions.first.update!(published: true)
        page_4 = create(:page, parent: page_3); page_4.revisions.first.update!(published: true)

        visit(new_admin_page_path())

        # Page 1 is hidden, page 2 is not published, page 3 is published and
        # top-level, page 4 is published but not top-level; so only expect to
        # see page 1 and page 3 in the parent options, since they're top-level.
        #
        expect(page).to have_select("page_page_id", with_options: ["Do not put into a menu", page_1.title, page_3.title])

        new_title = "Quick Brown Fox"

        fill_in("page_title", with: new_title)
        fill_in("page_body",  with: "<p>Lazy Dog</p>")
        select(page_3.title, from: "page_page_id")

        click_on("Publish page")
        spechelp_check_flash(:notice, "New page published")

        revision = Revision.find_by_title!(new_title)
        new_page = revision.revisable

        expect(new_page.parent).to eql(page_3)
      end

      it "creates top-level items by default" do
        p = create(:page) # (don't overwrite Capybara's "page" method!)
        p.revisions.first.update!(title: SecureRandom.uuid, published: true)

        visit(new_admin_page_path())

        expect(page).to have_select("page_page_id")

        new_title = "Quick Brown Fox"

        fill_in("page_title", with: new_title)
        fill_in("page_body",  with: "<p>Lazy Dog</p>")

        click_on("Publish page")
        spechelp_check_flash(:notice, "New page published")

        revision = Revision.find_by_title!(new_title)
        new_page = revision.revisable

        expect(new_page.parent).to be_nil
      end
    end # "context "parent-child" do"

    context "dynamic form behaviour", js: true do
      it "Redactor text entry works" do
        visit(new_admin_page_path())

        title            = "Quick Brown Fox"
        navigation_title = "Jumps Over The"
        body             = "Lazy Dog"

        fill_in("page_title",            with: title)
        fill_in("page_navigation_title", with: navigation_title)
        spechelp_fill_in_redactor(body)

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft page created")

        expect(    Page.count).to eql(1)
        expect(Revision.count).to eql(1)

        expect(Page.first.title           ).to eql(title)
        expect(Page.first.navigation_title).to eql(navigation_title)
        expect(Page.first.body            ).to eql("<p>#{body}</p>")

        expect(Page.first.revisions    ).to match_array(Revision.all)
        expect(Revision.first.current  ).to eql(true)
        expect(Revision.first.published).to eql(false)
      end

      it "Redactor image uploads work" do
        visit(new_admin_page_path())

        title            = "Quick Brown Fox"
        navigation_title = "Jumps Over The"
        body             = "Lazy Dog"

        fill_in("page_title",            with: title)
        fill_in("page_navigation_title", with: navigation_title)

        editor = find(:css, ".redactor_container .redactor-in")
        editor.click()

        find(:css, "#redactor_toolbar a.re-button.re-image").click()

        within(".redactor-modal-box") do
          expect(page).to have_css(".redactor-modal-header", text: "Image")
          expect(page).to have_css('input[name="file"][type="file"]', visible: false)

          # This is a bit of hack, relying on Redactor having a hidden file input
          # of name "file" which we can make visible and use for attachment. It's
          # easier than trying to simulate drag & drop - and we're here to test
          # our upload handling, not Redactor's UI implementation.
          #
          image_path = Rails.root.join("spec", "fixtures", "example.jpg")
          attach_file('file', image_path, make_visible: true)
        end

        # Must wait for the upload to be processed and written with <figure>
        # markup into the hidden textarea field for the page body; the modal
        # must also close.
        #
        expect(page).to     have_field("page_body", visible: false, with: /\<figure/)
        expect(page).to_not have_css(".redactor-modal-box")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft page created")

        expect(Page.first.title           ).to eql(title)
        expect(Page.first.navigation_title).to eql(navigation_title)
        expect(Page.first.body            ).to include("<figure")
        expect(Page.first.body            ).to include("example.jpg")

        expect(Page.first.revisions    ).to match_array(Revision.all)
        expect(Revision.first.current  ).to eql(true)
        expect(Revision.first.published).to eql(false)

        expect(Redactor3Rails::Asset.count                  ).to eql(1)
        expect(Redactor3Rails::Asset.first.data_file_name   ).to eql("example.jpg")
        expect(Redactor3Rails::Asset.first.data_content_type).to eql("image/jpeg")
      end

      context "page type" do
        it "changes make sections show and hide" do
          visit(new_admin_page_path())

          expect(page).to     have_field("page_title")
          expect(page).to     have_field("page_slug")
          expect(page).to     have_field("page_navigation_title")
          expect(page).to     have_select("page_page_type")
          expect(page).to     have_field("page_hidden")
          expect(page).to     have_field("page_raw_editor")
          expect(page).to     have_css(".redactor_container")
          expect(page).to_not have_field("page_form_selection_list_label")
          expect(page).to_not have_field("page_form_selection_list_contents")

          select("Booking form", from: "page_page_type")

          expect(page).to have_field("page_form_selection_list_label")
          expect(page).to have_field("page_form_selection_list_contents")

          select("Normal", from: "page_page_type")

          expect(page).to_not have_field("page_form_selection_list_label")
          expect(page).to_not have_field("page_form_selection_list_contents")

          select("Contact form", from: "page_page_type")

          expect(page).to have_field("page_form_selection_list_label")
          expect(page).to have_field("page_form_selection_list_contents")

          select("Blog", from: "page_page_type")

          expect(page).to_not have_css(".redactor_container")
          expect(page).to_not have_field("page_form_selection_list_label")
          expect(page).to_not have_field("page_form_selection_list_contents")
        end

        it "shows contact form fields initially for contact form page types" do
          p = create(:page, :contact_form)
          visit(edit_admin_page_path(p))

          expect(page).to have_select("page_page_type", selected: "Contact form")
          expect(page).to have_field("page_form_selection_list_label")
          expect(page).to have_field("page_form_selection_list_contents")
        end

        it "shows booking form fields initially for booking form page types" do
          p = create(:page, :booking_form)
          visit(edit_admin_page_path(p))

          expect(page).to have_select("page_page_type", selected: "Booking form")
          expect(page).to have_field("page_form_selection_list_label")
          expect(page).to have_field("page_form_selection_list_contents")
        end

        it "hides non-blog fields initially for blog page types" do
          p = create(:page, :blog)
          visit(edit_admin_page_path(p))

          expect(page).to     have_select("page_page_type", selected: "Blog")
          expect(page).to_not have_css(".redactor_container")
          expect(page).to_not have_field("page_form_selection_list_label")
          expect(page).to_not have_field("page_form_selection_list_contents")
        end
      end # "context "changes in page type" do"
    end # "context "dynamic form behaviour", js: true do"
  end # "context "creation" do"

  context "revision management" do
    context "with only one revision" do
      it "which is not published" do
        travel_to(Time.now) do
          p = create(:page)

          visit(admin_page_path(p))

          within "#publishing-info" do
            expect(page).to_not have_link("←")
            expect(page).to_not have_link("→")
            expect(page).to_not have_select("revision")
            expect(page).to     have_text("Draft (#{TimeZoneHelp.in_configured_time_zone(Time.now)})")
          end
        end
      end

      it "which is published" do
        p = create(:page)
        p.revisions.first.update!(published: true)

        visit(admin_page_path(p))

        within "#publishing-info" do
          expect(page).to_not have_link("←")
          expect(page).to_not have_link("→")
          expect(page).to_not have_select("revision")
          expect(page).to     have_text("Published")
        end
      end
    end # "context "with only one revision" do"

    context "navigation with many revisions" do
      around :each do | example |
        travel_to(Time.now) do
          example.run()
        end
      end

      before :each do
        p = create(
          :page,
          revisions: [
            build(:revision, :for_page, created_at: Time.now - 4.days, current: false, published: false),
            build(:revision, :for_page, created_at: Time.now - 3.days, current: false, published: true ),
            build(:revision, :for_page, created_at: Time.now - 2.days, current: true,  published: false),
          ]
        )

        # Automated maintenance of 'current' will lead to updated-at changes
        # so we can't set that in the factories above.
        #
        Revision.all.each { | revision | revision.update_column(:updated_at, revision.created_at) }

        visit(admin_page_path(p))

        # Should default to the published revision - that's the second in the
        # ordered-by-creation-date set.
        #
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.second.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.second.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.second.navigation_title)
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
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.third.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.third.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.third.navigation_title)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          click_on("→")
        end

        # Returned to the published one.
        #
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.second.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.second.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.second.navigation_title)

        within "#publishing-info" do
          expect(page).to have_button("→")
          expect(page).to have_button("←")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])

          click_on("→")
        end

        # Now showing the newest, a current draft.
        #
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.first.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.first.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.first.navigation_title)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          click_on("←")
        end

        # Returned to the published one.
        #
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.second.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.second.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.second.navigation_title)

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
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.third.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.third.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.third.navigation_title)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          select(revision_options()[2], from: "revision")
        end

        # Now showing the newest, a current draft.
        #
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.first.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.first.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.first.navigation_title)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          select(revision_options()[1], from: "revision")
        end

        # Returned to the published one.
        #
        expect(find(:css, "section.main_content")).to have_text(spechelp_strip_markup Revision.second.body)
        expect(find(:css, "nav.main_menu ul"    )).to have_text(                      Revision.second.title)
        expect(find(:css, "nav.main_menu h1"    )).to have_text(                      Revision.second.navigation_title)

        within "#publishing-info" do
          expect(page).to have_button("←")
          expect(page).to have_button("→")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])
        end
      end
    end # "context "navigation with many revisions" do"

    it "can roll back and edit, creating a new draft after a published revision" do
      visit(new_admin_page_path())

      title = "Quick Brown Fox"
      body  = "<p>Lazy Dog</p>"

      fill_in("page_title", with: title)
      fill_in("page_body",  with: body)

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit")

      fill_in("page_title", with: title + " 2")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(2)

      expect(Revision.pluck(:published)).to eql([true, false])
      expect(Revision.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit using this revision")

      expect(page).to have_field("page_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("page_title", with: title + " 3")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(3)

      expect(Revision.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.pluck(:published)).to eql([true, false, false])
      expect(Revision.pluck(:current  )).to eql([true, false, false])
    end

    # Copy-paste of the above test, but note the second edit is saved as a
    # draft rather than published.
    #
    it "can roll back and edit, creating a new draft after a now-abandoned prior current draft revision" do
      visit(new_admin_page_path())

      title = "Quick Brown Fox"
      body  = "<p>Lazy Dog</p>"

      fill_in("page_title", with: title)
      fill_in("page_body",  with: body)

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit")

      fill_in("page_title", with: title + " 2")

      # This is where this test starts to differ from the previous test.
      #
      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(2)

      # Note that we've now still got an older published draft and a new,
      # current draft; but we're going to step back and edit the published
      # original. The current draft should now end up a non-current abandoned
      # draft, with our edits appearing in a newest, third revision.
      #
      expect(Revision.pluck(:published)).to eql([false, true])
      expect(Revision.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit page, ignoring current draft")

      expect(page).to have_field("page_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("page_title", with: title + " 3")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(3)

      expect(Revision.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.pluck(:published)).to eql([true, false, false])
      expect(Revision.pluck(:current  )).to eql([true, false, false])
    end

    # This test starts much like the one above, up until stepping back to the
    # published revision after saving a draft. Then, though, it steps forward
    # and makes sure it can edit that still-current draft.
    #
    it "can 'roll back and forward again' and edit the current draft revision" do
      visit(new_admin_page_path())

      title = "Quick Brown Fox"
      body  = "<p>Lazy Dog</p>"

      fill_in("page_title", with: title)
      fill_in("page_body",  with: body)

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit")

      fill_in("page_title", with: title + " 2")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(2)

      expect(Revision.pluck(:published)).to eql([false, true])
      expect(Revision.pluck(:current  )).to eql([true, false])

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

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing draft")

      expect(page).to have_field("page_title", with: title + " 2")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(2)

      expect(Revision.pluck(:published)).to eql([true, false])
      expect(Revision.pluck(:current  )).to eql([true, false])
    end
  end # "context "revision management" do"

  context "raw editor" do
    it "can be selected when creating a draft" do
      visit(new_admin_page_path())

      title = "Quick Brown Fox"
      body  = "<p>Lazy Dog</p>"

      fill_in("page_title", with: title)
      fill_in("page_body",  with: body)

      check("page_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1)

      expect(Page.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_path(Page.first))
      expect(page).to have_css("textarea#page_body")
      expect(page).to have_field("page_body", with: body)

      fill_in("page_body", with: body + "<p>!</p>")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1) # (unchanged)

      expect(Page.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when creating a new published page" do
      visit(new_admin_page_path())

      title = "Quick Brown Fox"
      body  = "<p>Lazy Dog</p>"

      fill_in("page_title", with: title)
      fill_in("page_body",  with: body)

      check("page_raw_editor")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1)

      expect(Page.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_path(Page.first))
      expect(page).to have_css("textarea#page_body")
      expect(page).to have_field("page_body", with: body)

      fill_in("page_body", with: body + "<p>!</p>")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(2) # (we edited a published page, so there's a new revision)

      expect(Page.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when saving an edit of an existing page as a draft" do
      p = create(:page)

      expect(p.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_page_path(p))

      check("page_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1) # (existing draft was altered)

      expect(p.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_path(p))
      expect(page).to have_css("textarea#page_body")
      expect(page).to have_field("page_body", with: p.body)
    end

    it "can be selected when publishing an edit of an existing page" do
      p = create(:page)

      expect(p.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_page_path(p))

      check("page_raw_editor")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(    Page.count).to eql(1)
      expect(Revision.count).to eql(1) # (existing draft was published)

      expect(p.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_path(p))
      expect(page).to have_css("textarea#page_body")
      expect(page).to have_field("page_body", with: p.body)
    end
  end # "context "raw editor" do"

  context "contact forms" do
    before :each do
      allow_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return('')
    end

    it "allows menu items to be specified", js: true do
      visit(new_admin_page_path())

      title            = "Quick Brown Fox"
      navigation_title = "Jumps Over The"
      body             = "Lazy Dog"

      fill_in("page_title", with: title)
      fill_in("page_navigation_title", with: navigation_title)
      spechelp_fill_in_redactor(body)
      select("Contact form", from: "page_page_type")
      fill_in("page_form_selection_list_contents", with: "One\nTwo\nThree")

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      expect(Page.first.page_type       ).to eql(Page::PAGE_TYPE_CONTACT_FORM)
      expect(Page.first.title           ).to eql(title)
      expect(Page.first.navigation_title).to eql(navigation_title)
      expect(Page.first.body            ).to eql("<p>#{body}</p>")

      expect(page).to have_field("forms_contact_name")
      expect(page).to have_field("forms_contact_email")
      expect(page).to have_field("forms_contact_phone")
      expect(page).to have_css('label[for="forms_contact_menu_selection"]', text: "Please choose an item from the list")
      expect(page).to have_select("forms_contact_menu_selection", with_options: ["One", "Two", "Three"])
      expect(page).to have_field("forms_contact_message")
      expect(page).to have_button("Send message")
    end

    it "allows a menu title to be specified" do
      p = create(:page, :contact_form)
      visit(edit_admin_page_path(p))

      fill_in("page_form_selection_list_label", with: "Select a number")
      fill_in("page_form_selection_list_contents", with: "One\nTwo\nThree")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(page).to have_field("forms_contact_name")
      expect(page).to have_field("forms_contact_email")
      expect(page).to have_field("forms_contact_phone")
      expect(page).to have_css('label[for="forms_contact_menu_selection"]', text: "Select a number")
      expect(page).to have_select("forms_contact_menu_selection", with_options: ["One", "Two", "Three"])
      expect(page).to have_field("forms_contact_message")
      expect(page).to have_button("Send message")
    end

    it "supports having no menu" do
      p = create(:page, :contact_form)
      visit(edit_admin_page_path(p))

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(page).to     have_field("forms_contact_name")
      expect(page).to     have_field("forms_contact_email")
      expect(page).to     have_field("forms_contact_phone")
      expect(page).to_not have_css('label[for="forms_contact_menu_selection"]')
      expect(page).to_not have_select("forms_contact_menu_selection")
      expect(page).to     have_field("forms_contact_message")
      expect(page).to     have_button("Send message")
    end
  end # "context "contact forms" do"

  context "booking forms" do
    before :each do
      allow_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return('')
    end

    it "allows menu items to be specified", js: true do
      visit(new_admin_page_path())

      title            = "Quick Brown Fox"
      navigation_title = "Jumps Over The"
      body             = "Lazy Dog"

      fill_in("page_title", with: title)
      fill_in("page_navigation_title", with: navigation_title)
      spechelp_fill_in_redactor(body)
      select("Booking form", from: "page_page_type")
      fill_in("page_form_selection_list_contents", with: "One\nTwo\nThree")

      expect(page).to have_unchecked_field(:page_hide_date_and_time)

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      expect(Page.first.page_type       ).to eql(Page::PAGE_TYPE_BOOKING_FORM)
      expect(Page.first.title           ).to eql(title)
      expect(Page.first.navigation_title).to eql(navigation_title)
      expect(Page.first.body            ).to eql("<p>#{body}</p>")

      expect(page).to have_field("forms_booking_name")
      expect(page).to have_field("forms_booking_email")
      expect(page).to have_field("forms_booking_phone")
      expect(page).to have_css('label[for="forms_booking_menu_selection"]', text: "Please choose an item from the list")
      expect(page).to have_select("forms_booking_menu_selection", with_options: ["One", "Two", "Three"])
      expect(page).to have_field("forms_booking_date")
      expect(page).to have_field("forms_booking_time")
      expect(page).to have_field("forms_booking_notes")
      expect(page).to have_button("Send enquiry")
    end

    it "allows a menu title to be specified" do
      p = create(:page, :booking_form)
      visit(edit_admin_page_path(p))

      fill_in("page_form_selection_list_label", with: "Select a number")
      fill_in("page_form_selection_list_contents", with: "One\nTwo\nThree")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(page).to have_field("forms_booking_name")
      expect(page).to have_field("forms_booking_email")
      expect(page).to have_field("forms_booking_phone")
      expect(page).to have_css('label[for="forms_booking_menu_selection"]', text: "Select a number")
      expect(page).to have_select("forms_booking_menu_selection", with_options: ["One", "Two", "Three"])
      expect(page).to have_field("forms_booking_date")
      expect(page).to have_field("forms_booking_time")
      expect(page).to have_field("forms_booking_notes")
      expect(page).to have_button("Send enquiry")
    end

    it "supports having no menu" do
      p = create(:page, :booking_form)
      visit(edit_admin_page_path(p))

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(page).to     have_field("forms_booking_name")
      expect(page).to     have_field("forms_booking_email")
      expect(page).to     have_field("forms_booking_phone")
      expect(page).to_not have_css('label[for="forms_booking_menu_selection"]')
      expect(page).to_not have_select("forms_booking_menu_selection")
      expect(page).to     have_field("forms_booking_date")
      expect(page).to     have_field("forms_booking_time")
      expect(page).to     have_field("forms_booking_notes")
      expect(page).to     have_button("Send enquiry")
    end

    it "uses the default date-time hiding setting", js: true do
      allow(Rails.application.config.uk_org_pond_hcms).to receive(:booking_hide_date).and_return(true)

      visit(new_admin_page_path())
      select("Booking form", from: "page_page_type")

      expect(page).to have_checked_field(:page_hide_date_and_time)
    end

    it "can change the date/time hiding" do
      p = create(:page, :booking_form)
      visit(edit_admin_page_path(p))

      check("page_hide_date_and_time")

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(p.reload.hide_date_and_time).to eql(true)

      expect(page).to     have_field("forms_booking_name")
      expect(page).to     have_field("forms_booking_email")
      expect(page).to     have_field("forms_booking_phone")
      expect(page).to_not have_css('label[for="forms_booking_menu_selection"]')
      expect(page).to_not have_select("forms_booking_menu_selection")
      expect(page).to_not have_field("forms_booking_date")
      expect(page).to_not have_field("forms_booking_time")
      expect(page).to     have_field("forms_booking_notes")
      expect(page).to     have_button("Send enquiry")
    end
  end # "context "booking forms" do"

  # Blog articles are fully tested in 'articles_spec.rb', but basic blog
  # container tests are done here.
  #
  context "blog containers" do
    it "allows a container to be created", js: true do
      visit(new_admin_page_path())

      title            = "Quick Brown Fox"
      navigation_title = "Jumps Over The"

      fill_in("page_title", with: title)
      fill_in("page_navigation_title", with: navigation_title)
      select("Blog", from: "page_page_type")

      click_on("Publish page")
      spechelp_check_flash(:notice, "New page published")

      expect(Page.first.page_type       ).to eql(Page::PAGE_TYPE_BLOG)
      expect(Page.first.title           ).to eql(title)
      expect(Page.first.navigation_title).to eql(navigation_title)
      expect(Page.first.body            ).to be_empty
    end

    it "shows the expected CMS options" do
      p = create(:page, :blog)
      visit(edit_admin_page_path(p))

      click_on("Publish page")
      spechelp_check_flash(:notice, "Page changes published")

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("New article",    href: new_admin_page_article_path(page_id: p.id))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("List articles",  href: admin_page_articles_path(page_id: p.id))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Edit blog page", href: edit_admin_page_path(p))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("All pages",      href: admin_pages_path())
    end
  end

  context "lists" do
    context "display" do
      it "shows parents and children" do
        page_1 = create(:page, hidden: true  ); page_1.revisions.first.update!(published: true) # Not in menu because is hidden
        page_2 = create(:page                ) # Not in menu because is only a draft
        page_3 = create(:page                ); page_3.revisions.first.update!(published: true)
        page_4 = create(:page, parent: page_3); page_4.revisions.first.update!(published: true)
        page_5 = create(:page, :blog         ); page_5.revisions.first.update!(published: true)

        page_3.revisions << build(:revision, :for_page)
        page_3.save!

        visit(admin_pages_path())

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")
        row_4 = find(:css, "table tbody > tr:nth-child(4)")
        row_5 = find(:css, "table tbody > tr:nth-child(5)")

        # Title / Published? / Draft? / In menu? / Actions
        #
        expect(row_1).to have_text("#{page_1.title} No Yes No Show Edit Delete", exact: true)
        expect(row_2).to have_text("#{page_2.title} No Yes No Show Edit Delete", exact: true)
        expect(row_3).to have_text("#{page_3.title} Yes Yes Yes Show Edit Delete", exact: true)
        expect(row_4).to have_text("— #{page_4.title} Yes No Yes Show Edit Delete", exact: true) # "— " prefix for is-child
        expect(row_5).to have_text("#{page_5.title} Yes No Yes Show Edit Articles Delete", exact: true)

        # Check a few links. Column 1 - title, 2-4 - boolean, 5-6 - position
        # arrows, 7 - main actions, 8 - delete action.
        #
        expect(row_1.find(:css, "> td:nth-child(3)")).to have_link("Yes", href: admin_page_path(page_1.id, revision: page_1.revisions.last.id))
        expect(row_2.find(:css, "> td:nth-child(7)")).to have_link("Show", href: admin_page_path(page_2.slug))
        expect(row_3.find(:css, "> td:nth-child(7)")).to have_link("Edit", href: edit_admin_page_path(page_3.id))
        expect(row_4.find(:css, "> td:nth-child(8)")).to have_link("Delete", href: admin_page_path(page_4.id))
        expect(row_5.find(:css, "> td:nth-child(7)")).to have_link("Articles", href: admin_page_articles_path(page_5.id))
      end
    end # 'context "display" do'

    context "actions" do
      it "deletes with confirmation", js: true do
        p = create(:page)

        expect(Revision.count).to eql(1) # (self-check)

        visit(admin_pages_path())

        accept_confirm do
          find(:css, "table tbody tr td:last-child").click_link("Delete")
        end

        spechelp_check_flash(:notice, "Page deleted")

        expect(Page.exists?(p.id)).to eql(false)
        expect(Revision.count).to be_zero
      end
    end # 'context "actions" do'

    context "ordering" do
      it "moves pages up and down" do
        page_1 = create(:page)
        page_2 = create(:page)
        page_3 = create(:page)

        # Self-checks.
        #
        expect(page_1.position).to eql(1)
        expect(page_2.position).to eql(2)
        expect(page_3.position).to eql(3)

        visit(admin_pages_path())

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")

        expect(row_1).to have_text(page_1.title)
        expect(row_2).to have_text(page_2.title)
        expect(row_3).to have_text(page_3.title)

        expect(row_1).to_not have_button("↑")
        expect(row_1).to     have_button("↓")
        expect(row_2).to     have_button("↑")
        expect(row_2).to     have_button("↓")
        expect(row_3).to     have_button("↑")
        expect(row_3).to_not have_button("↓")

        row_2.click_button("↑")

        expect(page_1.reload.position).to eql(2)
        expect(page_2.reload.position).to eql(1)
        expect(page_3.reload.position).to eql(3)

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")

        expect(row_1).to have_text(page_2.title)
        expect(row_2).to have_text(page_1.title)
        expect(row_3).to have_text(page_3.title)

        expect(row_1).to_not have_button("↑")
        expect(row_1).to     have_button("↓")
        expect(row_2).to     have_button("↑")
        expect(row_2).to     have_button("↓")
        expect(row_3).to     have_button("↑")
        expect(row_3).to_not have_button("↓")
      end

      it "moves pages down" do
        page_1 = create(:page)
        page_2 = create(:page)
        page_3 = create(:page)

        # Self-checks.
        #
        expect(page_1.position).to eql(1)
        expect(page_2.position).to eql(2)
        expect(page_3.position).to eql(3)

        visit(admin_pages_path())

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")

        expect(row_1).to have_text(page_1.title)
        expect(row_2).to have_text(page_2.title)
        expect(row_3).to have_text(page_3.title)

        expect(row_1).to_not have_button("↑")
        expect(row_1).to     have_button("↓")
        expect(row_2).to     have_button("↑")
        expect(row_2).to     have_button("↓")
        expect(row_3).to     have_button("↑")
        expect(row_3).to_not have_button("↓")

        row_1.click_button("↓")

        expect(page_1.reload.position).to eql(2)
        expect(page_2.reload.position).to eql(1)
        expect(page_3.reload.position).to eql(3)

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")

        expect(row_1).to have_text(page_2.title)
        expect(row_2).to have_text(page_1.title)
        expect(row_3).to have_text(page_3.title)

        expect(row_1).to_not have_button("↑")
        expect(row_1).to     have_button("↓")
        expect(row_2).to     have_button("↑")
        expect(row_2).to     have_button("↓")
        expect(row_3).to     have_button("↑")
        expect(row_3).to_not have_button("↓")
      end
    end # 'context "ordering" do'
  end # 'context "lists" do'"
end
