require "spec_helper.rb"

RSpec.describe "Admin - encounters" do
  include ApplicationHelper

  before :each do
    spechelp_log_in()
  end

  context "creation" do
    it "can create in a draft state " do
      visit(admin_encounters_path())

      click_on("New encounter")

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      seats    = "15"
      price    = "49.99"
      physical = "4.99"
      physname = "gift card"

      fill_in("encounter_title",          with: title)
      fill_in("encounter_summary",        with: summary)
      fill_in("encounter_body",           with: body)
      fill_in("encounter_location",       with: location)
      fill_in("encounter_price_per_seat", with: price)
      fill_in("encounter_price_physical", with: physical)
      fill_in("encounter_name_physical",  with: physname)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      click_on("Save draft")
      spechelp_check_flash(:notice, "New draft encounter created")

      expect(Encounter.count).to eql(1)
      expect( Revision.count).to eql(1)

      expect(Encounter.first.title         ).to eql(title)
      expect(Encounter.first.slug          ).to eql(title.parameterize)
      expect(Encounter.first.summary       ).to eql(summary)
      expect(Encounter.first.body          ).to eql(body)
      expect(Encounter.first.location      ).to eql(location)
      expect(Encounter.first.price_per_seat).to eql((price.to_f * 100).to_i)
      expect(Encounter.first.price_physical).to eql((physical.to_f * 100).to_i)
      expect(Encounter.first.name_physical ).to eql(physname)

      expect(Encounter.first.revisions.size           ).to eql(1)
      expect(Encounter.first.revisions.first.current  ).to eql(true)
      expect(Encounter.first.revisions.first.published).to eql(false)

      expect(page).to     have_current_path(admin_encounter_path(id: Encounter.first.slug), ignore_query: true)
      expect(page).to_not have_text("There might be price information included in this encounter's summary or description")

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Continue editing encounter draft", href: edit_admin_encounter_path(Encounter.first))
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Add encounter",                    href: new_admin_encounter_path())
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("List encounters",                  href: admin_encounters_path())
      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Page management",                  href: admin_pages_path())

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing encounter draft")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_current_path(edit_admin_encounter_path(Encounter.first))
      expect(page).to have_field("encounter_title", with: title)
    end

    it "can create in a published state" do
      visit(new_admin_encounter_path())

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      price    = "49" # Note no ".00", but we're still expecting 4900 "cents"

      fill_in("encounter_title",          with: title)
      fill_in("encounter_summary",        with: summary)
      fill_in("encounter_body",           with: body)
      fill_in("encounter_location",       with: location)
      fill_in("encounter_price_per_seat", with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "New encounter published")

      expect(Encounter.count).to eql(1)
      expect( Revision.count).to eql(1)

      expect(Encounter.first.title         ).to eql(title)
      expect(Encounter.first.slug          ).to eql(title.parameterize)
      expect(Encounter.first.summary       ).to eql(summary)
      expect(Encounter.first.body          ).to eql(body)
      expect(Encounter.first.location      ).to eql(location)
      expect(Encounter.first.price_per_seat).to eql((price.to_f * 100).to_i)

      expect(Encounter.first.revisions.size           ).to eql(1)
      expect(Encounter.first.revisions.first.current  ).to eql(true)
      expect(Encounter.first.revisions.first.published).to eql(true)

      expect(page).to     have_current_path(admin_encounter_path(id: Encounter.first.slug))
      expect(page).to_not have_text("There might be price information included in this encounter's summary or description")

      expect(find(:css, "section.footer_content nav.cms_menu")).to have_link("Edit encounter")

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit encounter")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_current_path(edit_admin_encounter_path(Encounter.first))
      expect(page).to have_field("encounter_title", with: title)
    end

    it "validates" do
      visit(new_admin_encounter_path())

      click_on("Publish encounter")

      expect(page).to have_css(".field_error_messages", text: "Title must be provided")
      expect(page).to have_css(".field_error_messages", text: "Poster photo must be provided")
      expect(page).to have_css(".field_error_messages", text: "Brief summary must be provided")
      expect(page).to have_css(".field_error_messages", text: "Encounter details must be provided")
    end

    context "price warnings" do
      it "are shown based on the summary" do
        visit(admin_encounters_path())
        click_on("New encounter")

        symbol   = Money::Currency.new(Hcms.config.currency).symbol
        title    = "Quick Brown Fox"
        summary  = "Jumps #{symbol} Over The"
        body     = "<p>Lazy Dog</p>"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        seats    = "15"
        price    = "49.99"
        physical = "4.99"
        physname = "gift card"

        fill_in("encounter_title",          with: title)
        fill_in("encounter_summary",        with: summary)
        fill_in("encounter_body",           with: body)
        fill_in("encounter_location",       with: location)
        fill_in("encounter_price_per_seat", with: price)
        fill_in("encounter_price_physical", with: physical)
        fill_in("encounter_name_physical",  with: physname)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("encounter_encounter_hero_image", image_path)
        click_on("Publish encounter")

        spechelp_check_flash(:notice, "New encounter published")
        expect(page).to have_current_path(admin_encounter_path(id: Encounter.first.slug))
        spechelp_check_flash(:alert, "There might be price information included in this encounter's summary or description")
      end

      it "are shown based on the body" do
        visit(admin_encounters_path())
        click_on("New encounter")

        symbol   = Money::Currency.new(Hcms.config.currency).symbol
        title    = "Quick Brown Fox"
        summary  = "Jumps Over The"
        body     = "<p>Lazy #{symbol} Dog</p>"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        seats    = "15"
        price    = "49.99"
        physical = "4.99"
        physname = "gift card"

        fill_in("encounter_title",          with: title)
        fill_in("encounter_summary",        with: summary)
        fill_in("encounter_body",           with: body)
        fill_in("encounter_location",       with: location)
        fill_in("encounter_price_per_seat", with: price)
        fill_in("encounter_price_physical", with: physical)
        fill_in("encounter_name_physical",  with: physname)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("encounter_encounter_hero_image", image_path)
        click_on("Publish encounter")

        spechelp_check_flash(:notice, "New encounter published")
        expect(page).to have_current_path(admin_encounter_path(id: Encounter.first.slug))
        spechelp_check_flash(:alert, "There might be price information included in this encounter's summary or description")
      end
    end # 'context "price warnings" do'

    context "dynamic behaviour", js: true do
      it "Redactor text entry works" do
        visit(new_admin_encounter_path())

        title    = "Quick Brown Fox"
        summary  = "Jumps Over The"
        body     = "Lazy Dog"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        seats    = "15"
        price    = "48.1" # Deliberate "mis-type"; expecting 4810 "cents"
        physical = "4.99"
        physname = "gift card"

        fill_in("encounter_title",          with: title)
        fill_in("encounter_summary",        with: summary)
        fill_in("encounter_location",       with: location)
        fill_in("encounter_price_per_seat", with: price)
        fill_in("encounter_price_physical", with: physical)
        fill_in("encounter_name_physical",  with: physname)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("encounter_encounter_hero_image", image_path)

        spechelp_fill_in_redactor(body, for_type: "encounter")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft encounter created")

        expect(Encounter.count).to eql(1)
        expect( Revision.count).to eql(1)

        expect(Encounter.first.title         ).to eql(title)
        expect(Encounter.first.slug          ).to eql(title.parameterize)
        expect(Encounter.first.summary       ).to eql(summary)
        expect(Encounter.first.body          ).to eql("<p>#{body}</p>")
        expect(Encounter.first.location      ).to eql(location)
        expect(Encounter.first.price_per_seat).to eql((price.to_f * 100).to_i)
        expect(Encounter.first.price_physical).to eql((physical.to_f * 100).to_i)
        expect(Encounter.first.name_physical ).to eql(physname)

        expect(Encounter.first.revisions.size           ).to eql(1)
        expect(Encounter.first.revisions.first.current  ).to eql(true)
        expect(Encounter.first.revisions.first.published).to eql(false)
      end

      it "Redactor image uploads work" do
        visit(new_admin_encounter_path())

        title    = "Quick Brown Fox"
        summary  = "Jumps Over The"
        body     = "Lazy Dog"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        price    = "49.99"

        fill_in("encounter_title",           with: title)
        fill_in("encounter_summary",         with: summary)
        fill_in("encounter_location",        with: location)
        fill_in("encounter_price_per_seat",  with: price)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("encounter_encounter_hero_image", image_path)

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

        expect(page).to     have_field("encounter_body", visible: false, with: /\<figure/)
        expect(page).to_not have_css(".redactor-modal-box")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft encounter created")

        expect(Encounter.first.title  ).to eql(title)
        expect(Encounter.first.slug   ).to eql(title.parameterize)
        expect(Encounter.first.summary).to eql(summary)
        expect(Encounter.first.body   ).to include("<figure")
        expect(Encounter.first.body   ).to include("example.jpg")

        expect(Encounter.first.revisions.size           ).to eql(1)
        expect(Encounter.first.revisions.first.current  ).to eql(true)
        expect(Encounter.first.revisions.first.published).to eql(false)

        expect(Redactor3Rails::Asset.count                  ).to eql(1)
        expect(Redactor3Rails::Asset.first.data_file_name   ).to eql("example.jpg")
        expect(Redactor3Rails::Asset.first.data_content_type).to eql("image/jpeg")
      end

      it "Redactor file uploads work" do
        visit(new_admin_encounter_path())

        title    = "Quick Brown Fox"
        summary  = "Jumps Over The"
        body     = "Lazy Dog"
        location = "1 Courtenay Place, Wellington 6011 New Zealand"
        price    = "49.99"

        fill_in("encounter_title",          with: title)
        fill_in("encounter_summary",        with: summary)
        fill_in("encounter_location",       with: location)
        fill_in("encounter_price_per_seat", with: price)

        image_path = Rails.root.join("spec", "fixtures", "example.jpg")
        attach_file("encounter_encounter_hero_image", image_path)

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

        expect(page).to     have_field("encounter_body", visible: false, with: /example\.pdf/)
        expect(page).to_not have_css(".redactor-modal-box")

        click_on("Save draft")
        spechelp_check_flash(:notice, "New draft encounter created")

        expect(Encounter.first.title  ).to eql(title)
        expect(Encounter.first.slug   ).to eql(title.parameterize)
        expect(Encounter.first.summary).to eql(summary)
        expect(Encounter.first.body   ).to include('/example.pdf" data-file="')
        expect(Encounter.first.body   ).to include(">Example PDF file</a>")

        expect(Encounter.first.revisions.size           ).to eql(1)
        expect(Encounter.first.revisions.first.current  ).to eql(true)
        expect(Encounter.first.revisions.first.published).to eql(false)

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
          encounter = create(:encounter)

          visit(admin_encounter_path(encounter))

          within "#publishing-info" do
            expect(page).to_not have_link("←")
            expect(page).to_not have_link("→")
            expect(page).to_not have_select("revision")
            expect(page).to     have_text("Draft (#{TimeZoneHelp.in_configured_time_zone(Time.now)})")
          end
        end
      end

      it "which is published" do
        encounter = create(:encounter)
        encounter.revisions.first.update!(published: true)

        visit(admin_encounter_path(encounter))

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
        encounter = create(
          :encounter,
          revisions: [
            build(:revision, :for_encounter, created_at: Time.now - 4.days, current: false, published: false),
            build(:revision, :for_encounter, created_at: Time.now - 3.days, current: false, published: true ),
            build(:revision, :for_encounter, created_at: Time.now - 2.days, current: true,  published: false),
          ]
        )

        # Automated maintenance of 'current' will lead to updated-at changes
        # so we can't set that in the factories above.
        #
        Revision.for_encounters.each { | revision | revision.update_column(:updated_at, revision.created_at) }

        visit(admin_encounter_path(encounter))

        # Should default to the published revision - that's the second in the
        # ordered-by-creation-date set.
        #
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.second.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.summary)
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
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.third.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.third.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.third.summary)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          click_on("→")
        end

        # Returned to the published one.
        #
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.second.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.summary)

        within "#publishing-info" do
          expect(page).to have_button("→")
          expect(page).to have_button("←")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])

          click_on("→")
        end

        # Now showing the newest, a current draft.
        #
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.first.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.first.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.first.summary)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          click_on("←")
        end

        # Returned to the published one.
        #
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.second.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.summary)

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
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.third.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.third.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.third.summary)

        within "#publishing-info" do
          expect(page).to_not have_button("←")
          expect(page).to     have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[0])

          select(revision_options()[2], from: "revision")
        end

        # Now showing the newest, a current draft.
        #
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.first.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.first.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.first.summary)

        within "#publishing-info" do
          expect(page).to     have_button("←")
          expect(page).to_not have_button("→")
          expect(page).to     have_select("revision", with_options: revision_options(), selected: revision_options()[2])

          select(revision_options()[1], from: "revision")
        end

        # Returned to the published one.
        #
        displayed_encounter = find(:css, "section.main_content article")
        expect(displayed_encounter).to have_text(spechelp_strip_markup Revision.for_encounters.second.body)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.title)
        expect(displayed_encounter).to have_text(                      Revision.for_encounters.second.summary)

        within "#publishing-info" do
          expect(page).to have_button("←")
          expect(page).to have_button("→")
          expect(page).to have_select("revision", with_options: revision_options(), selected: revision_options()[1])
        end
      end
    end # 'context "navigation with many revisions" do'

    it "can roll back and edit, creating a new draft after a published revision" do
      visit(new_admin_encounter_path())

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      price    = "49.99"

      fill_in("encounter_title",          with: title)
      fill_in("encounter_summary",        with: summary)
      fill_in("encounter_body",           with: body)
      fill_in("encounter_location",       with: location)
      fill_in("encounter_price_per_seat", with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "New encounter published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit encounter")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      fill_in("encounter_title", with: title + " 2")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Encounter changes published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(2)

      expect(Revision.for_encounters.pluck(:published)).to eql([true, false])
      expect(Revision.for_encounters.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit using this encounter revision")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_field("encounter_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("encounter_title", with: title + " 3")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Encounter changes published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(3)

      expect(Revision.for_encounters.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.for_encounters.pluck(:published)).to eql([true, false, false])
      expect(Revision.for_encounters.pluck(:current  )).to eql([true, false, false])
    end

    # Copy-paste of the above test, but note the second edit is saved as a
    # draft rather than published.
    #
    it "can roll back and edit, creating a new draft after a now-abandoned prior current draft revision" do
      visit(new_admin_encounter_path())

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      price    = "49.99"

      fill_in("encounter_title",          with: title)
      fill_in("encounter_summary",        with: summary)
      fill_in("encounter_body",           with: body)
      fill_in("encounter_location",       with: location)
      fill_in("encounter_price_per_seat", with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "New encounter published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit encounter")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      fill_in("encounter_title", with: title + " 2")

      # This is where this test starts to differ from the previous test.
      #
      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(2)

      # Note that we've now still got an older published draft and a new,
      # current draft; but we're going to step back and edit the published
      # original. The current draft should now end up a non-current abandoned
      # draft, with our edits appearing in a newest, third revision.
      #
      expect(Revision.for_encounters.pluck(:published)).to eql([false, true])
      expect(Revision.for_encounters.pluck(:current  )).to eql([true, false])

      within "#publishing-info" do
        click_on("←")
      end

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit encounter, ignoring current draft")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_field("encounter_title", with: title) # (without the newer revision's " 2" appended)

      fill_in("encounter_title", with: title + " 3")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Encounter changes published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(3)

      expect(Revision.for_encounters.pluck(:title    )).to eql([title + " 3", title + " 2", title])
      expect(Revision.for_encounters.pluck(:published)).to eql([true, false, false])
      expect(Revision.for_encounters.pluck(:current  )).to eql([true, false, false])
    end

    # This test starts much like the one above, up until stepping back to the
    # published revision after saving a draft. Then, though, it steps forward
    # and makes sure it can edit that still-current draft.
    #
    it "can 'roll back and forward again' and edit the current draft revision" do
      visit(new_admin_encounter_path())

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      price    = "49.99"

      fill_in("encounter_title",          with: title)
      fill_in("encounter_summary",        with: summary)
      fill_in("encounter_body",           with: body)
      fill_in("encounter_location",       with: location)
      fill_in("encounter_price_per_seat", with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "New encounter published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1)

      find(:css, "section.footer_content nav.cms_menu").click_on("Edit encounter")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      fill_in("encounter_title", with: title + " 2")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Changes saved as draft")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(2)

      expect(Revision.for_encounters.pluck(:published)).to eql([false, true])
      expect(Revision.for_encounters.pluck(:current  )).to eql([true, false])

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

      find(:css, "section.footer_content nav.cms_menu").click_on("Continue editing encounter draft")
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      expect(page).to have_field("encounter_title", with: title + " 2")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Encounter changes published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(2)

      expect(Revision.for_encounters.pluck(:published)).to eql([true, false])
      expect(Revision.for_encounters.pluck(:current  )).to eql([true, false])
    end
  end # 'context "revision management" do'

  context "raw editor" do
    it "can be selected when creating a draft" do
      visit(new_admin_encounter_path())

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      price    = "49.99"

      fill_in("encounter_title",          with: title)
      fill_in("encounter_summary",        with: summary)
      fill_in("encounter_body",           with: body)
      fill_in("encounter_location",       with: location)
      fill_in("encounter_price_per_seat", with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      check("encounter_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1)

      expect(Encounter.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_encounter_path(Encounter.first))
      expect(page).to have_css("textarea#encounter_body")
      expect(page).to have_field("encounter_body", with: body)

      fill_in("encounter_body", with: body + "<p>!</p>")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Encounter changes published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1)

      expect(Encounter.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when creating a new published page" do
      visit(new_admin_encounter_path())

      title    = "Quick Brown Fox"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"
      price    = "49.99"

      fill_in("encounter_title",          with: title)
      fill_in("encounter_summary",        with: summary)
      fill_in("encounter_body",           with: body)
      fill_in("encounter_location",       with: location)
      fill_in("encounter_price_per_seat", with: price)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      check("encounter_raw_editor")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1)

      expect(Encounter.first.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_encounter_path(Encounter.first))
      expect(page).to have_css("textarea#encounter_body")
      expect(page).to have_field("encounter_body", with: body)

      fill_in("encounter_body", with: body + "<p>!</p>")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Encounter changes published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(2) # (we edited a published encounter, so there's a new revision)

      expect(Encounter.first.body).to eql(body + "<p>!</p>")
    end

    it "can be selected when saving an edit of an existing page as a draft" do
      encounter = create(:encounter)

      expect(encounter.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_encounter_path(encounter))
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      check("encounter_raw_editor")

      click_on("Save draft")
      spechelp_check_flash(:notice, "Editor selection altered.")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1) # (existing draft was altered)

      expect(encounter.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_encounter_path(encounter))
      expect(page).to have_css("textarea#encounter_body")
      expect(page).to have_field("encounter_body", with: encounter.body)
    end

    it "can be selected when publishing an edit of an existing page" do
      encounter = create(:encounter)

      expect(encounter.raw_editor).to eql(false) # (self-check)

      visit(edit_admin_encounter_path(encounter))
      find(:css, "details > summary", text: "Expand to edit other attributes").click()

      check("encounter_raw_editor")

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Editor selection altered and other changes, if any, published")

      expect(              Encounter.count).to eql(1)
      expect(Revision.for_encounters.count).to eql(1) # (existing draft was altered)

      expect(encounter.reload.raw_editor).to eql(true)

      expect(page).to have_current_path(edit_admin_encounter_path(encounter))
      expect(page).to have_css("textarea#encounter_body")
      expect(page).to have_field("encounter_body", with: encounter.body)
    end
  end # 'context "raw editor" do'

  context "category selection and position auto-management" do
    def create_in_category(category)
      visit(new_admin_encounter_path())

      title    = "Quick Brown Fox #{Encounter.count + 1}"
      summary  = "Jumps Over The"
      body     = "<p>Lazy Dog</p>"
      location = "1 Courtenay Place, Wellington 6011 New Zealand"

      fill_in("encounter_title",    with: title)
      fill_in("encounter_summary",  with: summary)
      fill_in("encounter_body",     with: body)
      fill_in("encounter_location", with: location)
      fill_in("encounter_category", with: category)

      image_path = Rails.root.join("spec", "fixtures", "example.jpg")
      attach_file("encounter_encounter_hero_image", image_path)

      encounter_ids_before = Encounter.pluck(:id)

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "New encounter published")

      return Encounter.where.not(id: encounter_ids_before).first
    end

    def edit_category(encounter, new_category)
      visit(edit_admin_encounter_path(encounter))

      find(:css, "details > summary", text: "Expand to edit other attributes").click()
      select("Add new", from: "encounter_category_chooser")
      fill_in("encounter_category", with: new_category)

      click_on("Publish encounter")
      spechelp_check_flash(:notice, "Encounter changes published")
    end

    it "handles a complex sequence" do

      # Create things in a varying order and show that either existing
      # category positions are picked up or new category positions are added.
      #
      encounter_1_no_category = create_in_category("")
      encounter_2_no_category = create_in_category("")
      encounter_3_category_A  = create_in_category("A")
      encounter_4_no_category = create_in_category("")
      encounter_5_category_A  = create_in_category("A")
      encounter_6_category_B  = create_in_category("B")
      encounter_7_category_C  = create_in_category("C")

      all_created_encounters  = [
        encounter_1_no_category,
        encounter_2_no_category,
        encounter_3_category_A,
        encounter_4_no_category,
        encounter_5_category_A,
        encounter_6_category_B,
        encounter_7_category_C,
      ]

      expect(encounter_1_no_category.category_position).to eql(1)
      expect(encounter_2_no_category.category_position).to eql(1)
      expect(encounter_4_no_category.category_position).to eql(1)

      expect(encounter_3_category_A.category_position).to eql(2)
      expect(encounter_5_category_A.category_position).to eql(2)

      expect(encounter_6_category_B.category_position).to eql(3)

      expect(encounter_7_category_C.category_position).to eql(4)

      # Now start editing things and check the position recalculations. If the
      # only encounter in B is changed to something new, then it would've left
      # a "hole" that category C should fall down into and then it should
      # have gained a new position at the end of the list.
      #
      edit_category(encounter_6_category_B, "B-2")
      all_created_encounters.map(&:reload)

      expect(encounter_1_no_category.category_position).to eql(1)
      expect(encounter_2_no_category.category_position).to eql(1)
      expect(encounter_4_no_category.category_position).to eql(1)

      expect(encounter_3_category_A.category_position).to eql(2)
      expect(encounter_5_category_A.category_position).to eql(2)

      expect(encounter_7_category_C.category_position).to eql(3) # Shuffled down

      #                 (Now in "B-2")
      expect(encounter_6_category_B.category_position).to eql(4) # New position

      # If we edit "A"s to be in category "C" there are no "A"s left, so there
      # is a hole that should then be filled by lowering higher positions. But
      # that would include the already-higher category C number and the item
      # that got edited should track that properly.
      #
      # So when we move the first one - nothing shuffles. When we move the last
      # one - it shuffles.
      #
      edit_category(encounter_3_category_A, "C")
      all_created_encounters.map(&:reload)

      expect(encounter_1_no_category.category_position).to eql(1)
      expect(encounter_2_no_category.category_position).to eql(1)
      expect(encounter_4_no_category.category_position).to eql(1)

      expect(encounter_5_category_A.category_position).to eql(2)

      #                  (Now in "C")
      expect(encounter_3_category_A.category_position).to eql(3) # Matches position
      expect(encounter_7_category_C.category_position).to eql(3) # Not shuffled

      #                 (Now in "B-2")
      expect(encounter_6_category_B.category_position).to eql(4)

      edit_category(encounter_5_category_A, "C")
      all_created_encounters.map(&:reload)

      expect(encounter_1_no_category.category_position).to eql(1)
      expect(encounter_2_no_category.category_position).to eql(1)
      expect(encounter_4_no_category.category_position).to eql(1)

      #                  (Now in "C")
      expect(encounter_3_category_A.category_position).to eql(2) # Shuffled down
      #             (Now also in "C")
      expect(encounter_5_category_A.category_position).to eql(2) # Shuffled down
      expect(encounter_7_category_C.category_position).to eql(2) # Shuffled down

      #                 (Now in "B-2")
      expect(encounter_6_category_B.category_position).to eql(3) # Shuffled down

      # The opposite now; remove category from all of the above, and note that
      # eventually things shuffle but there's no "zero" / accidental decrement.
      #
      edit_category(encounter_3_category_A, "")
      edit_category(encounter_5_category_A, "")
      edit_category(encounter_7_category_C, "")
      all_created_encounters.map(&:reload)

      expect(encounter_1_no_category.category_position).to eql(1)
      expect(encounter_2_no_category.category_position).to eql(1)
      #                   (Now in no category)
      expect(encounter_3_category_A.category_position ).to eql(1)
      expect(encounter_4_no_category.category_position).to eql(1)
      #                   (Now in no category)
      expect(encounter_5_category_A.category_position ).to eql(1)
      #                   (Now in no category)
      expect(encounter_7_category_C.category_position ).to eql(1)

      #                 (Now in "B-2")
      expect(encounter_6_category_B.category_position).to eql(2) # Shuffled down again
    end
  end # 'context "category selection and position auto-management" do'

  context "lists" do
    context "display" do
      it "shows details" do
        encounter_1 = create(:encounter) # Draft
        encounter_2 = create(:encounter); encounter_2.revisions.first.update!(published: true)
        encounter_3 = create(:encounter); encounter_3.revisions.first.update!(published: true)

        encounter_1.update(category_position: 3)
        encounter_2.update(category_position: 2)
        encounter_3.update(category_position: 1)

        encounter_3.category = "Goliaths"
        encounter_3.revisions << build(:revision, :for_encounter)
        encounter_3.save!

        encounter_order = EncounterOrder.create!(
          encounter:                 encounter_3,
          name:                      "Fred Flintstone",
          email:                     "fred@example.com",
          address:                   "Wellington",
          starts_at:                 Time.now + 1.week,
          number_of_seats:           3,
          has_physical:              false,
          user_chooses_has_physical: false,
          amount_owed:               3 * encounter_3.price_per_seat,
        )

        encounter_order.pay_state!

        visit(admin_encounters_path())

        expect(find(:css, "section.main_content h1")).to have_text("Encounters")

        row_1 = find(:css, "table tbody > tr:nth-child(1)")
        row_2 = find(:css, "table tbody > tr:nth-child(2)")
        row_3 = find(:css, "table tbody > tr:nth-child(3)")

        # Title / Published? / Draft? / Actions
        #
        # Note reverse order - created-at ASC sorting.
        #
        expect(row_1).to have_text("#{encounter_3.title} Yes Yes Goliaths Bookings / Show / Edit Delete", exact: true)
        expect(row_2).to have_text("#{encounter_2.title} Yes No Uncategorised Bookings / Show / Edit Delete", exact: true)
        expect(row_3).to have_text("#{encounter_1.title} No Yes Uncategorised Show / Edit Delete", exact: true)

        # Check a few links. Column 1 - encounter title, 2-3 - boolean, 4-7
        # category and category move arrow cells, 7 - booking and main actions,
        # 8 - delete action.
        #
        expect(row_1.find(:css, "> td:nth-child(3)")).to have_link("Yes",      href: admin_encounter_path(encounter_3, revision: encounter_3.revisions.last.id))
        expect(row_1.find(:css, "> td:nth-child(7)")).to have_link("Bookings", href: admin_encounter_encounter_orders_path(encounter_id: encounter_3.slug))
        expect(row_2.find(:css, "> td:nth-child(7)")).to have_link("Show",     href: admin_encounter_path(id: encounter_2.slug))
        expect(row_3.find(:css, "> td:nth-child(7)")).to have_link("Edit",     href: edit_admin_encounter_path( encounter_1.id))
      end

      it "links to the main 'all pages' list" do
        visit(admin_encounters_path())

        expect(page).to have_link('Back to "All pages" list', href: admin_pages_path())
      end
    end # 'context "display" do'

    context "actions" do
      it "deletes with confirmation", js: true do
        encounter = create(:encounter)

        expect(Revision.count).to eql(1) # (self-check)

        visit(admin_encounters_path())

        accept_confirm do
          find(:css, "table tbody tr td:last-child").click_link("Delete")
        end

        spechelp_check_flash(:notice, "Encounter deleted")

        expect(Encounter.exists?(encounter.id)).to eql(false)

        expect(Revision.count).to eql(0)
      end
    end # 'context "actions" do'

    context "ordering" do

      # We'll use this setup, ordered by category position and assume that
      # there are no data migration or issues or bugs leading to duplicated
      # category positions, even though there *is* some tolerance for that.:
      #
      #   Zodiac
      #   Aardvark
      #   Uncat
      #   Uncat
      #   Banana
      #   Banana
      #
      def get_rows
        1.upto(6).map do | row_number |
          find(:css, "table tbody > tr:nth-child(#{row_number})")
        end
      end
      def check_row_text
        rows = get_rows()
        Encounter.unscoped.order(:category_position).each_with_index do | encounter, index |
          expect(rows[index]).to have_text(encounter.category)
        end
      end
      before :each do
        @encounter_aardvark = create(:encounter, category: "Aardvark", category_position: 2)
        @encounter_banana_1 = create(:encounter, category: "Banana",   category_position: 4)
        @encounter_banana_2 = create(:encounter, category: "Banana",   category_position: 4)
        @encounter_uncat_1  = create(:encounter,                       category_position: 3)
        @encounter_uncat_2  = create(:encounter,                       category_position: 3)
        @encounter_zodiac   = create(:encounter, category: "Zodiac",   category_position: 1)

        # Do lots of sanity checks before any further movement-specific tests.

        visit(admin_encounters_path())

        check_row_text()

        # Zodiac can move down, but not up since it's already on the first row.
        # Aardvark and both Uncategorised can move either way. The "Banana" set
        # come last but they're both the same category, so *both* of them -
        # given they move as a group - should have buttons to move up only, but
        # not down.

        rows = get_rows()

        expect(rows[0]).to_not have_button("↑"); expect(rows[0]).to     have_button("↓")
        expect(rows[1]).to     have_button("↑"); expect(rows[1]).to     have_button("↓")
        expect(rows[2]).to     have_button("↑"); expect(rows[2]).to     have_button("↓")
        expect(rows[3]).to     have_button("↑"); expect(rows[3]).to     have_button("↓")
        expect(rows[4]).to     have_button("↑"); expect(rows[4]).to_not have_button("↓")
        expect(rows[5]).to     have_button("↑"); expect(rows[6]).to_not have_button("↓")
      end

      after :each do
        check_row_text()
      end

      it "moves category groups up - group moves past group, using group row's first button" do
        rows = get_rows()
        rows[4].click_button("↑") # First Banana row - move up

        expect(@encounter_zodiac  .reload.category_position).to eql(1) # Unchanged
        expect(@encounter_aardvark.reload.category_position).to eql(2) # Unchanged
        expect(@encounter_banana_1.reload.category_position).to eql(3) # Moved
        expect(@encounter_banana_2.reload.category_position).to eql(3)
        expect(@encounter_uncat_1 .reload.category_position).to eql(4) # Also moved
        expect(@encounter_uncat_2 .reload.category_position).to eql(4)
      end

      it "moves category groups up - group moves past group, using group row's second button" do
        rows = get_rows()
        rows[5].click_button("↑") # Second Banana row - move up

        expect(@encounter_zodiac  .reload.category_position).to eql(1) # Unchanged
        expect(@encounter_aardvark.reload.category_position).to eql(2) # Unchanged
        expect(@encounter_banana_1.reload.category_position).to eql(3) # Moved
        expect(@encounter_banana_2.reload.category_position).to eql(3)
        expect(@encounter_uncat_1 .reload.category_position).to eql(4) # Also moved
        expect(@encounter_uncat_2 .reload.category_position).to eql(4)
      end

      it "moves category groups up - group push between individual row categories" do
        rows = get_rows()
        rows[4].click_button("↑") # First Banana row - move up
        rows = get_rows()
        rows[2].click_button("↑") # Relocated first Banana row - move up again

        expect(@encounter_zodiac  .reload.category_position).to eql(1) # Unchanged
        expect(@encounter_banana_1.reload.category_position).to eql(2) # Moved
        expect(@encounter_banana_2.reload.category_position).to eql(2)
        expect(@encounter_aardvark.reload.category_position).to eql(3) # Also moved
        expect(@encounter_uncat_1 .reload.category_position).to eql(4) # Also moved
        expect(@encounter_uncat_2 .reload.category_position).to eql(4)
      end

      it "moves category groups down - group moves past group, using group row's first button" do
        rows = get_rows()
        rows[2].click_button("↓") # First Uncategorised row - move down

        expect(@encounter_zodiac  .reload.category_position).to eql(1) # Unchanged
        expect(@encounter_aardvark.reload.category_position).to eql(2) # Unchanged
        expect(@encounter_banana_1.reload.category_position).to eql(3) # Moved
        expect(@encounter_banana_2.reload.category_position).to eql(3)
        expect(@encounter_uncat_1 .reload.category_position).to eql(4) # Also moved
        expect(@encounter_uncat_2 .reload.category_position).to eql(4)
      end

      it "moves category groups down - group moves past group, using group row's second button" do
        rows = get_rows()
        rows[3].click_button("↓") # Second Uncategorised row - move down

        expect(@encounter_zodiac  .reload.category_position).to eql(1) # Unchanged
        expect(@encounter_aardvark.reload.category_position).to eql(2) # Unchanged
        expect(@encounter_banana_1.reload.category_position).to eql(3) # Moved
        expect(@encounter_banana_2.reload.category_position).to eql(3)
        expect(@encounter_uncat_1 .reload.category_position).to eql(4) # Also moved
        expect(@encounter_uncat_2 .reload.category_position).to eql(4)
      end

      it "moves category groups down - inidivudal item moves between other individual item" do
        rows = get_rows()
        rows[0].click_button("↓") # Zodiac row - move down

        expect(@encounter_aardvark.reload.category_position).to eql(1) # Moved
        expect(@encounter_zodiac  .reload.category_position).to eql(2) # Also moved
        expect(@encounter_uncat_1 .reload.category_position).to eql(3) # Unchanged
        expect(@encounter_uncat_2 .reload.category_position).to eql(3)
        expect(@encounter_banana_1.reload.category_position).to eql(4) # Unchanged
        expect(@encounter_banana_2.reload.category_position).to eql(4)
      end

      it "moves category groups down - inidivudal item moves between groups" do
        rows = get_rows()
        rows[1].click_button("↓") # Aardvark row - move down

        expect(@encounter_zodiac  .reload.category_position).to eql(1) # Unchanged
        expect(@encounter_uncat_1 .reload.category_position).to eql(2) # Moved
        expect(@encounter_uncat_2 .reload.category_position).to eql(2)
        expect(@encounter_aardvark.reload.category_position).to eql(3) # Also moved
        expect(@encounter_banana_1.reload.category_position).to eql(4) # Unchanged
        expect(@encounter_banana_2.reload.category_position).to eql(4)
      end
    end # 'context "ordering" do'
  end # 'context "lists" do'"
end
