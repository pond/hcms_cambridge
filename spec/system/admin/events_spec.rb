require "spec_helper.rb"

RSpec.describe "Admin - events" do
  include ApplicationHelper

  before :each do
    spechelp_log_in()

    @page = create(:page, :events)
    @page.revisions.first.update!(published: true)
  end

  context "creation" do
    it "can create in a draft state " do
      visit(admin_pages_path())

      find(:css, "section.main_content table tbody tr:first-child").click_on("Events")

      expect(find(:css, "section.main_content h1")).to have_text("Event list “#{@page.title}”")

      click_on("New event")

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      click_on("Save draft")
      spechelp_check_flash(:notice, "New draft event created")

      expect(    Page.count).to eql(1)
      expect(   Event.count).to eql(1)
      expect(Revision.count).to eql(2)

      expect(Event.first.title          ).to eql(title)
      expect(Event.first.slug           ).to eql(title.parameterize)
      expect(Event.first.summary        ).to eql(summary)
      expect(Event.first.body           ).to eql(body)
      expect(Event.first.location       ).to eql(location)
      expect(Event.first.starts_at      ).to eql(starts)
      expect(Event.first.ends_at        ).to eql(ends)
      expect(Event.first.number_of_seats).to eql(seats.to_i)
      expect(Event.first.price_per_seat ).to eql((price.to_f * 100).to_i)

      expect(Event.first.revisions.size           ).to eql(1)
      expect(Event.first.revisions.first.current  ).to eql(true)
      expect(Event.first.revisions.first.published).to eql(false)

      expect(Event.first.hidden).to eql(false)
      expect(Event.first.state).to eql("presales")

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Continue editing event draft", href: edit_admin_page_event_path(Page.first, Event.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Add event",                    href: new_admin_page_event_path(Page.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("List events",                  href: admin_page_events_path(Page.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Page management",              href: admin_pages_path())

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing event draft")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_current_path(edit_admin_page_event_path(Page.first, Event.first))
      expect(page).to have_field("event_title", with: title)
    end

    it "can create in a published state" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49" # Note no ".00", but we're still expecting 4900 "cents"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      click_on("Publish event")
      spechelp_check_flash(:notice, "New event published")

      expect(    Page.count).to eql(1)
      expect(   Event.count).to eql(1)
      expect(Revision.count).to eql(2)

      expect(Event.first.title          ).to eql(title)
      expect(Event.first.slug           ).to eql(title.parameterize)
      expect(Event.first.summary        ).to eql(summary)
      expect(Event.first.body           ).to eql(body)
      expect(Event.first.location       ).to eql(location)
      expect(Event.first.starts_at      ).to eql(starts)
      expect(Event.first.ends_at        ).to eql(ends)
      expect(Event.first.number_of_seats).to eql(seats.to_i)
      expect(Event.first.price_per_seat ).to eql((price.to_f * 100).to_i)

      expect(Event.first.revisions.size           ).to eql(1)
      expect(Event.first.revisions.first.current  ).to eql(true)
      expect(Event.first.revisions.first.published).to eql(true)

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Edit event")

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit event")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_current_path(edit_admin_page_event_path(Page.first, Event.first))
      expect(page).to have_field("event_title", with: title)
    end

    it "validates" do
      visit(new_admin_page_event_path(@page))

      click_on("Publish event")

      expect(page).to have_css(".field_error_messages", text: "Title must be provided")
      expect(page).to have_css(".field_error_messages", text: "Poster photo must be provided")
      expect(page).to have_css(".field_error_messages", text: "Brief summary must be provided")
      expect(page).to have_css(".field_error_messages", text: "Start date and time must be in the future")
      expect(page).to have_css(".field_error_messages", text: "Event details must be provided")
    end

    context "dynamic behaviour", js: true do
      it "Redactor text entry works" do
        visit(new_admin_page_event_path(@page))

        title    = "Quick Brown Fox"
        summary  = "Jumps Over The"
        body     = "Lazy Dog"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        starts   = (Time.current + 1.day).midnight + 18.hours
        ends     = (Time.current + 1.day).midnight + 21.hours
        seats    = "15"
        price    = "48.1" # Deliberate "mis-type"; expecting 4810 "cents"

        fill_in("event_title",           with: title)
        fill_in("event_summary",         with: summary)
        fill_in("event_location",        with: location)
        fill_in("event_starts_at",       with: starts.iso8601)
        fill_in("event_ends_at",         with: ends.iso8601)
        fill_in("event_number_of_seats", with: seats)
        fill_in("event_price_per_seat",  with: price)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("event_event_hero_image", image_path)

        spechelp_fill_in_redactor(body, for_type: "event")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft event created")

        expect(    Page.count).to eql(1)
        expect(   Event.count).to eql(1)
        expect(Revision.count).to eql(2)

        expect(Event.first.title          ).to eql(title)
        expect(Event.first.slug           ).to eql(title.parameterize)
        expect(Event.first.summary        ).to eql(summary)
        expect(Event.first.body           ).to eql("<p>#{body}</p>")
        expect(Event.first.location       ).to eql(location)
        expect(Event.first.starts_at      ).to eql(starts)
        expect(Event.first.ends_at        ).to eql(ends)
        expect(Event.first.number_of_seats).to eql(seats.to_i)
        expect(Event.first.price_per_seat ).to eql((price.to_f * 100).to_i)

        expect(Event.first.revisions.size           ).to eql(1)
        expect(Event.first.revisions.first.current  ).to eql(true)
        expect(Event.first.revisions.first.published).to eql(false)
      end

      it "Redactor image uploads work" do
        visit(new_admin_page_event_path(@page))

        title    = "Quick Brown Fox"
        summary  = "Jumps Over The"
        body     = "Lazy Dog"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        starts   = (Time.current + 1.day).midnight + 18.hours
        ends     = (Time.current + 1.day).midnight + 21.hours
        seats    = "15"
        price    = "49.99"

        fill_in("event_title",           with: title)
        fill_in("event_summary",         with: summary)
        fill_in("event_location",        with: location)
        fill_in("event_starts_at",       with: starts.iso8601)
        fill_in("event_ends_at",         with: ends.iso8601)
        fill_in("event_number_of_seats", with: seats)
        fill_in("event_price_per_seat",  with: price)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("event_event_hero_image", image_path)

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

        expect(page).to     have_field("event_body", visible: false, with: /\<figure/)
        expect(page).to_not have_css(".redactor-modal-box")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft event created")

        expect(Event.first.title  ).to eql(title)
        expect(Event.first.slug   ).to eql(title.parameterize)
        expect(Event.first.summary).to eql(summary)
        expect(Event.first.body   ).to include("<figure")
        expect(Event.first.body   ).to include("example.jpg")

        expect(Event.first.revisions.size           ).to eql(1)
        expect(Event.first.revisions.first.current  ).to eql(true)
        expect(Event.first.revisions.first.published).to eql(false)

        expect(Redactor3Rails::Asset.count                  ).to eql(1)
        expect(Redactor3Rails::Asset.first.data_file_name   ).to eql("example.jpg")
        expect(Redactor3Rails::Asset.first.data_content_type).to eql("image/jpeg")
      end

      it "Redactor file uploads work" do
        visit(new_admin_page_event_path(@page))

        title    = "Quick Brown Fox"
        summary  = "Jumps Over The"
        body     = "Lazy Dog"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        starts   = (Time.current + 1.day).midnight + 18.hours
        ends     = (Time.current + 1.day).midnight + 21.hours
        seats    = "15"
        price    = "49.99"

        fill_in("event_title",           with: title)
        fill_in("event_summary",         with: summary)
        fill_in("event_location",        with: location)
        fill_in("event_starts_at",       with: starts.iso8601)
        fill_in("event_ends_at",         with: ends.iso8601)
        fill_in("event_number_of_seats", with: seats)
        fill_in("event_price_per_seat",  with: price)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("event_event_hero_image", image_path)

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

        expect(page).to     have_field("event_body", visible: false, with: /example\.pdf/)
        expect(page).to_not have_css(".redactor-modal-box")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft event created")

        expect(Event.first.title  ).to eql(title)
        expect(Event.first.slug   ).to eql(title.parameterize)
        expect(Event.first.summary).to eql(summary)
        expect(Event.first.body   ).to include('/example.pdf" data-file="')
        expect(Event.first.body   ).to include(">Example PDF file</a>")

        expect(Event.first.revisions.size           ).to eql(1)
        expect(Event.first.revisions.first.current  ).to eql(true)
        expect(Event.first.revisions.first.published).to eql(false)

        expect(Redactor3Rails::Asset.count                  ).to eql(1)
        expect(Redactor3Rails::Asset.first.data_file_name   ).to eql("example.pdf")
        expect(Redactor3Rails::Asset.first.data_content_type).to eql("application/pdf")
      end
    end # context "dynamic behaviour", js: true do'
  end # 'context "creation" do'

  context "revision management" do
    context "with only one revision" do
      it "which is not published" do
        travel_to(Time.now) do
          event = create(:event, page: @page)

          visit(admin_page_event_path(@page, event))

          within "#publishing-info" do
            expect(page).to_not have_link("←")
            expect(page).to_not have_link("→")
            expect(page).to_not have_select("revision")
            expect(page).to     have_text("Draft (#{TimeZoneHelp.in_configured_time_zone(Time.now)})")
          end
        end
      end

      it "which is published" do
        event = create(:event, page: @page)
        event.revisions.first.update!(published: true)

        visit(admin_page_event_path(@page, event))

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
        event = create(
          :event,
          page:      @page,
          revisions: [
            build(:revision, :for_event, created_at: Time.now - 4.days, current: false, published: false),
            build(:revision, :for_event, created_at: Time.now - 3.days, current: false, published: true ),
            build(:revision, :for_event, created_at: Time.now - 2.days, current: true,  published: false),
          ]
        )

        # Automated maintenance of 'current' will lead to updated-at changes
        # so we can't set that in the factories above.
        #
        Revision.for_events.each { | revision | revision.update_column(:updated_at, revision.created_at) }

        visit(admin_page_event_path(@page, event))

        # Should default to the published revision - that's the second in the
        # ordered-by-creation-date set.
        #
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.second.body)
        expect(displayed_event).to have_text(                      Revision.for_events.second.title)
        expect(displayed_event).to have_text(                      Revision.for_events.second.summary)
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
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.third.body)
        expect(displayed_event).to have_text(                      Revision.for_events.third.title)
        expect(displayed_event).to have_text(                      Revision.for_events.third.summary)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          click_on("→")
        end

        # Returned to the published one.
        #
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.second.body)
        expect(displayed_event).to have_text(                      Revision.for_events.second.title)
        expect(displayed_event).to have_text(                      Revision.for_events.second.summary)

        within "#publishing-info" do
          expect(page).to have_button("→")
          expect(page).to have_button("←")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])

          click_on("→")
        end

        # Now showing the newest, a current draft.
        #
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.first.body)
        expect(displayed_event).to have_text(                      Revision.for_events.first.title)
        expect(displayed_event).to have_text(                      Revision.for_events.first.summary)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          click_on("←")
        end

        # Returned to the published one.
        #
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.second.body)
        expect(displayed_event).to have_text(                      Revision.for_events.second.title)
        expect(displayed_event).to have_text(                      Revision.for_events.second.summary)

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
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.third.body)
        expect(displayed_event).to have_text(                      Revision.for_events.third.title)
        expect(displayed_event).to have_text(                      Revision.for_events.third.summary)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          select(revision_options()[2], from: "revision")
        end

        # Now showing the newest, a current draft.
        #
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.first.body)
        expect(displayed_event).to have_text(                      Revision.for_events.first.title)
        expect(displayed_event).to have_text(                      Revision.for_events.first.summary)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          select(revision_options()[1], from: "revision")
        end

        # Returned to the published one.
        #
        displayed_event = find(:css, "section.main_content article")
        expect(displayed_event).to have_text(spechelp_strip_markup Revision.for_events.second.body)
        expect(displayed_event).to have_text(                      Revision.for_events.second.title)
        expect(displayed_event).to have_text(                      Revision.for_events.second.summary)

        within "#publishing-info" do
          expect(page).to have_button("←")
          expect(page).to have_button("→")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])
        end
      end
    end # 'context "navigation with many revisions" do'

    it "can roll back and edit, creating a new draft after a published revision" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      click_on("Publish event")
      spechelp_check_flash(:notice, "New event published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit event")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      fill_in("event_title", with: title + " 2")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Event changes published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(2)

      expect(Revision.for_events.pluck(:published)).to eql([true, false])
      expect(Revision.for_events.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit using this event revision")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_field("event_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("event_title", with: title + " 3")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Event changes published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(3)

      expect(Revision.for_events.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.for_events.pluck(:published)).to eql([true, false, false])
      expect(Revision.for_events.pluck(:current  )).to eql([true, false, false])
    end

    # Copy-paste of the above test, but note the second edit is saved as a
    # draft rather than published.
    #
    it "can roll back and edit, creating a new draft after a now-abandoned prior current draft revision" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      click_on("Publish event")
      spechelp_check_flash(:notice, "New event published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit event")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      fill_in("event_title", with: title + " 2")

      # This is where this test starts to differ from the previous test.
      #
      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(2)

      # Note that we've now still got an older published draft and a new,
      # current draft; but we're going to step back and edit the published
      # original. The current draft should now end up a non-current abandoned
      # draft, with our edits appearing in a newest, third revision.
      #
      expect(Revision.for_events.pluck(:published)).to eql([false, true])
      expect(Revision.for_events.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit event, ignoring current draft")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_field("event_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("event_title", with: title + " 3")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Event changes published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(3)

      expect(Revision.for_events.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.for_events.pluck(:published)).to eql([true, false, false])
      expect(Revision.for_events.pluck(:current  )).to eql([true, false, false])
    end

    # This test starts much like the one above, up until stepping back to the
    # published revision after saving a draft. Then, though, it steps forward
    # and makes sure it can edit that still-current draft.
    #
    it "can 'roll back and forward again' and edit the current draft revision" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      click_on("Publish event")
      spechelp_check_flash(:notice, "New event published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit event")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      fill_in("event_title", with: title + " 2")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(2)

      expect(Revision.for_events.pluck(:published)).to eql([false, true])
      expect(Revision.for_events.pluck(:current  )).to eql([true, false])

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

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing event draft")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_field("event_title", with: title + " 2")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Event changes published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(2)

      expect(Revision.for_events.pluck(:published)).to eql([true, false])
      expect(Revision.for_events.pluck(:current  )).to eql([true, false])
    end
  end # 'context "revision management" do'

  context "raw editor" do
    it "can be selected when creating a draft" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      check("event_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      expect(Event.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_event_path(@page, Event.first))
      expect(page).to have_css("textarea#event_body")
      expect(page).to have_field("event_body", with: body)

      fill_in("event_body", with: body + "<p>!</p>")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Event changes published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      expect(Event.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when creating a new published page" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      check("event_raw_editor")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      expect(Event.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_event_path(@page, Event.first))
      expect(page).to have_css("textarea#event_body")
      expect(page).to have_field("event_body", with: body)

      fill_in("event_body", with: body + "<p>!</p>")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Event changes published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(2) # (we edited a published event, so there's a new revision)

      expect(Event.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when saving an edit of an existing page as a draft" do
      event = create(:event, page: @page)

      expect(event.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_page_event_path(@page, event))
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      check("event_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1) # (existing draft was altered)

      expect(event.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_event_path(@page, event))
      expect(page).to have_css("textarea#event_body")
      expect(page).to have_field("event_body", with: event.body)
    end

    it "can be selected when publishing an edit of an existing page" do
      event = create(:event, page: @page)

      expect(event.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_page_event_path(@page, event))
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      check("event_raw_editor")

      click_on("Publish event")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1) # (existing draft was altered)

      expect(event.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_page_event_path(@page, event))
      expect(page).to have_css("textarea#event_body")
      expect(page).to have_field("event_body", with: event.body)
    end
  end # 'context "raw editor" do'

  context "hidden flag and initial state" do
    it "can set as 'hidden'" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      check("event_hidden")

      click_on("Publish event")
      spechelp_check_flash(:notice, "New event published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      expect(Event.first.hidden).to eql(true)
      expect(Event.first.state).to eql("presales")
    end

    it "can start directly in a public sales state" do
      visit(new_admin_page_event_path(@page))

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      starts   = (Time.current + 1.day).midnight + 18.hours
      ends     = (Time.current + 1.day).midnight + 21.hours
      seats    = "15"
      price    = "49.99"

      fill_in("event_title",           with: title)
      fill_in("event_summary",         with: summary)
      fill_in("event_body",            with: body)
      fill_in("event_location",        with: location)
      fill_in("event_starts_at",       with: starts.iso8601)
      fill_in("event_ends_at",         with: ends.iso8601)
      fill_in("event_number_of_seats", with: seats)
      fill_in("event_price_per_seat",  with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("event_event_hero_image", image_path)

      choose("event_state_public_purchases")

      click_on("Publish event")
      spechelp_check_flash(:notice, "New event published")

      expect(              Event.count).to eql(1)
      expect(Revision.for_events.count).to eql(1)

      expect(Event.first.hidden).to eql(false)
      expect(Event.first.state).to eql("public_purchases")
    end
  end # 'context "hidden flag and initial state" do'

  context "lists" do
    context "display" do
      it "shows details" do
        event_1 = create(:event, page: @page) # Draft
        event_2 = create(:event, page: @page); event_2.revisions.first.update!(published: true)
        event_3 = create(:event, page: @page); event_3.revisions.first.update!(published: true)

        event_1.update(starts_at: Time.now + 1.day - 3.seconds, ends_at: Time.now + 1.day - 3.seconds + 1.hour)
        event_2.update(starts_at: Time.now + 1.day - 4.seconds, ends_at: Time.now + 1.day - 4.seconds + 1.hour)
        event_3.update(starts_at: Time.now + 1.day - 5.seconds, ends_at: Time.now + 1.day - 5.seconds + 1.hour)

        event_1.update!(hidden: true)

        event_2.start_public_purchases!

        event_3.revisions << build(:revision, :for_event)
        event_3.save!

        order = Order.create!(
          event:           event_3,
          name:            "Fred Flintstone",
          email:           "fred@example.com",
          number_of_seats: 3,
          amount_owed:     3 * event_3.price_per_seat
        )

        order.reserve_state!

        visit(admin_page_events_path(@page))

        expect(find(:css, "section.main_content h1")).to have_text("Event list “#{@page.title}”")

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")

        # Title / Published? / Draft? / In menu? / Actions
        #
        # Note reverse order - starts-at ASC sorting.
        #
        expect(row_1).to have_text("#{event_3.title} #{event_3.human_state} #{apphelp_human_time(event_3.starts_at, date_only: true)} Yes No Yes 👤 Orders (3) Show Edit Delete", exact: true)
        expect(row_2).to have_text("#{event_2.title} #{event_2.human_state} #{apphelp_human_time(event_2.starts_at, date_only: true)} Yes No No 🟠 Orders Show Edit Delete", exact: true)
        expect(row_3).to have_text("#{event_1.title} #{event_1.human_state} #{apphelp_human_time(event_1.starts_at, date_only: true)} No Yes Yes – Show Edit Delete", exact: true)

        # Check a few links. Column 1 - event title, 2 - start date,
        # 3-5 - boolean, 6 - order action, 7 - main actions, 8 - delete action.
        #
        expect(row_1.find(:css, "> td:nth-child(5)")).to have_link("Yes", href: admin_page_event_path(@page, event_3, revision: event_3.revisions.last.id))
        expect(row_1.find(:css, "> td:nth-child(6)")).to have_link("Orders", href: admin_page_event_orders_path(page_id: @page.slug, event_id: event_3.slug))
        expect(row_2.find(:css, "> td:nth-child(7)")).to have_link("Show", href: admin_page_event_path(page_id: @page.slug, id: event_2.slug))
        expect(row_3.find(:css, "> td:nth-child(7)")).to have_link("Edit", href: edit_admin_page_event_path(page_id: @page.id, id: event_1.id))
      end

      it "links to the event page" do
        visit(admin_page_events_path(@page))

        expect(page).to have_link("View event grid", href: admin_page_path(@page.slug))
      end

      it "links to the main 'all pages' list" do
        visit(admin_page_events_path(@page))

        expect(page).to have_link('Back to "All pages" list', href: admin_pages_path())
      end
    end # 'context "display" do'

    context "actions" do
      it "deletes with confirmation", js: true do
        event = create(:event, page: @page)

        expect(Revision.count).to eql(2) # (self-check)

        visit(admin_page_events_path(@page))

        accept_confirm do
          find(:css, "table tbody tr td:last-child").click_link("Delete")
        end

        spechelp_check_flash(:notice, "Event deleted")

        expect(Event.exists?(event.id)).to eql(false)

        expect(Revision.count).to eql(1)
      end
    end # 'context "actions" do'
  end # 'context "lists" do'"
end
