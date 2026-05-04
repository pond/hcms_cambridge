require "spec_helper.rb"
require_relative "shared_examples/footer.rb"

RSpec.describe "Encounters" do
  include ApplicationHelper

  before :each do
    allow_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return("")
  end

  context "navigation" do
    it "redirects to the Admin page if logged in" do
      encounter = create(:encounter)
      encounter.revisions.first.update!(published: true)

      visit(encounter_path(encounter.slug))
      expect(page).to have_current_path(encounter_path(encounter.slug)) # No redirection

      spechelp_log_in()

      visit(encounter_path(encounter.slug))
      expect(page).to have_current_path(admin_encounter_path(encounter.slug)) # Redirected to admin
    end
  end # 'context "navigation" do'

  context "shared" do
    let(:path_to_test) { root_path() }

    before :each do
      @encounter = create(:encounter)
      @encounter.revisions.first.update!(published: true)
    end

    context "when viewing an encounter" do
      let(:path_to_test) { encounter_path(@encounter.slug) }
      it_behaves_like "a public page footer"
    end
  end # 'context "shared" do'

  context "viewing" do
    it "hides drafts once published revisions are available" do
      encounter = create(:encounter)

      visit encounter_path(encounter)

      # Draft is shown, since there's nothing else to show! Admins might by
      # accident share a link to an Encounter without realising they never hit
      # the "Publish" button for the first ever draft, so this is more helpful
      # than showing some 'not published yet' message.
      #
      expect(page).to have_text(spechelp_strip_markup encounter.body)

      encounter.revisions.first.update!(published: true)

      encounter_published_revision = encounter.revisions.first
      encounter_draft_revision     = build(:revision, :for_encounter) # Draft, shouldn't show up
      encounter.revisions << encounter_draft_revision
      encounter.save!

      visit encounter_path(encounter)

      expect(page).to     have_text(encounter_published_revision.title)
      expect(page).to     have_text(encounter_published_revision.summary)
      expect(page).to     have_text(spechelp_strip_markup encounter_published_revision.body)
      expect(page).to     have_css("section.encounter-poster img[alt=\"#{encounter_published_revision.title}\"]")

      expect(page).to_not have_text(encounter_draft_revision.title)
      expect(page).to_not have_text(encounter_draft_revision.summary)
      expect(page).to_not have_text(spechelp_strip_markup encounter_draft_revision.body)
      expect(page).to_not have_css("section.encounter-poster img[alt=\"#{encounter_draft_revision.title}\"]")
    end

    it "shows correct event pricing and includes the enquiry form inline" do
      [
        create(:encounter),
        create(:encounter, :physical_free),
        create(:encounter, :physical_none),
        create(:encounter, :free),
        create(:encounter, :free, :physical_free),
        create(:encounter, :free, :physical_none),
        create(:encounter, price_on_application: true),
        create(:encounter, :physical_free, price_on_application: true),
        create(:encounter, :physical_none, price_on_application: true),
        create(:encounter, :free, price_on_application: true),
        create(:encounter, :free, :physical_free, price_on_application: true),
        create(:encounter, :free, :physical_none, price_on_application: true),
      ].each do | encounter |
        encounter.revisions.first.update!(published: true)

        visit encounter_path(encounter)

        details = page.find(:css, "section.encounter-meta")
        price   = apphelp_money(
          encounter.price_per_seat,
          currency:       encounter.currency,
          free_of_charge: encounter.free_of_charge?,
          poa:            encounter.price_on_application?
        )
        physical = apphelp_money(
          encounter.price_physical || 0,
          currency:       encounter.currency,
          free_of_charge: encounter.physical_aspect_free_of_charge?,
        )

        expect(details).to have_text("Price per seat")
        expect(details).to have_text(price)

        if encounter.has_physical_aspect? && ! encounter.price_on_application?
          expect(details).to have_text("optional")
          expect(details).to have_text(encounter.name_physical)
          expect(details).to have_text(physical)
        else
          expect(details).to_not have_text("optional")

          if encounter.name_physical.present?
            expect(details).to_not have_text(encounter.name_physical)
            expect(details).to_not have_text(physical)
          end
        end

        expect(page).to have_field("forms_booking_name")
        expect(page).to have_field("forms_booking_email")
        expect(page).to have_field("forms_booking_phone")
        expect(page).to have_field("forms_booking_notes")
      end
    end

    context "enquiry form" do
      around :each do | example |
        old_country_code = Phonelib.default_country
        Phonelib.default_country = "NZ"
        example.run()
      ensure
        Phonelib.default_country = old_country_code
      end

      before :each do
        allow(Hcms.config).to receive(:hide_booking_date).and_return(false)
        allow(Hcms.config).to receive(:booking_email    ).and_return("booking@example.com")
        allow(Hcms.config).to receive(:site_name        ).and_return("Site Under Test")

        # There must be a Home page for after-submission redirection
        #
        page = create(:page)
        page.revisions.first.update!(published: true)

        @encounter = create(:encounter)
        @encounter.revisions.first.update!(published: true)

        visit(encounter_path(@encounter))
      end

      it "displays, validates and submits" do
        expect(page).to     have_field("forms_booking_name")
        expect(page).to     have_field("forms_booking_email")
        expect(page).to     have_field("forms_booking_phone")
        expect(page).to_not have_field("forms_booking_date")
        expect(page).to_not have_field("forms_booking_time")
        expect(page).to     have_field("forms_booking_notes")

        click_on("Send enquiry")

        expect(page).to have_css("div.field_error_messages", text: "Name must be provided")
        expect(page).to have_css("div.field_error_messages", text: "E-mail address must be provided")
        expect(page).to have_css("div.field_error_messages", text: "Notes must be provided")

        fill_in("forms_booking_phone", with: "123")
        click_on("Send enquiry")

        expect(page).to have_css("div.field_error_messages", text: "Telephone number format not recognised")

        fill_in("forms_booking_phone", with: "021 000 000") # Given enforced NZ dial prefix, that's reasonable...
        click_on("Send enquiry")

        expect(page).to_not have_css("div.field_error_messages", text: "Telephone number format not recognised")

        fill_in("forms_booking_phone", with: "07855 000 000") # ...but this is not, as that's UK format (+44)
        click_on("Send enquiry")

        expect(page).to have_css("div.field_error_messages", text: "Telephone number format not recognised")

        fill_in("forms_booking_name",  with: "Fred Flintstone")
        fill_in("forms_booking_email", with: "fred@example.com")
        fill_in("forms_booking_phone", with: "+64 021 000 000") # (note intentional "+64 0...", which should be accepted)
        fill_in("forms_booking_notes", with: "Quick Brown Fox\nOther text")

        click_on("Send enquiry")
        spechelp_check_flash(:notice, "Your booking enquiry has been sent")

        delivered = spechelp_decode_multipart()

        expect(delivered.email.from   ).to eql(["booking@example.com"])
        expect(delivered.email.to     ).to eql(["booking@example.com"])
        expect(delivered.email.subject).to eql("[Site Under Test] \"#{@encounter.title}\" - booking enquiry")

        expect(delivered.text).to include("Fred Flintstone")
        expect(delivered.text).to include("fred@example.com")
        expect(delivered.text).to include("+64 021 000 000")
        expect(delivered.text).to include("Quick Brown Fox\nOther text")

        expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
        spechelp_check_mailto(
          html:    delivered.html,
          email:   "fred@example.com",
          subject: "Your Site Under Test booking enquiry"
        )
        spechelp_check_tel(
          html:  delivered.html,
          phone: '+64 021 000 000'
        )
        expect(delivered.html).to include(">Quick Brown Fox\n<br>Other text</p>")
      end

      it "is OK with no phone number" do
        fill_in("forms_booking_name",  with: "Fred Flintstone")
        fill_in("forms_booking_email", with: "fred@example.com")
        fill_in("forms_booking_notes", with: "Quick Brown Fox")

        click_on("Send enquiry")
        spechelp_check_flash(:notice, "Your booking enquiry has been sent")

        delivered = spechelp_decode_multipart()

        expect(delivered.email.from   ).to eql(["booking@example.com"])
        expect(delivered.email.to     ).to eql(["booking@example.com"])
        expect(delivered.email.subject).to eql("[Site Under Test] \"#{@encounter.title}\" - booking enquiry")

        expect(delivered.text).to include("Fred Flintstone")
        expect(delivered.text).to include("fred@example.com")
        expect(delivered.text).to include("Quick Brown Fox")

        expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
        spechelp_check_mailto(
          html:    delivered.html,
          email:   "fred@example.com",
          subject: "Your Site Under Test booking enquiry"
        )
        expect(delivered.html).to include(">Quick Brown Fox</p>")
      end

      # This is a future-facing test in case Encounter gets altered to either
      # dynamically allow show-hide, or always show the date-time fields.
      #
      # At the of writing, it hard-codes those to "off" but they're supported
      # as a theoretical potential future need since the booking form has them
      # anyway.
      #
      it "would obey 'show date and time' if so configured" do
        allow_any_instance_of(Encounter).to receive(:hide_date_and_time).and_return(false)
        visit(page.current_path)

        expect(page).to have_field("forms_booking_name")
        expect(page).to have_field("forms_booking_email")
        expect(page).to have_field("forms_booking_phone")
        expect(page).to have_field("forms_booking_date")
        expect(page).to have_field("forms_booking_time")
        expect(page).to have_field("forms_booking_notes")

        fill_in("forms_booking_name",  with: "Fred Flintstone")
        fill_in("forms_booking_email", with: "fred@example.com")
        fill_in("forms_booking_phone", with: "+64 021 000 000") # (note intentional "+64 0...", which should be accepted)
        fill_in("forms_booking_date",  with: "20/01/#{Date.today.year + 2}")
        fill_in("forms_booking_time",  with: "11:30")
        fill_in("forms_booking_notes", with: "Quick Brown Fox\nOther text")

        click_on("Send enquiry")
        spechelp_check_flash(:notice, "Your booking enquiry has been sent")

        delivered = spechelp_decode_multipart()

        expect(delivered.email.from   ).to eql(["booking@example.com"])
        expect(delivered.email.to     ).to eql(["booking@example.com"])
        expect(delivered.email.subject).to eql("[Site Under Test] \"#{@encounter.title}\" - booking enquiry")

        expect(delivered.text).to include("Fred Flintstone")
        expect(delivered.text).to include("fred@example.com")
        expect(delivered.text).to include("+64 021 000 000")
        expect(delivered.text).to include("20/01/#{Date.today.year + 2}")
        expect(delivered.text).to include("11:30")
        expect(delivered.text).to include("Quick Brown Fox\nOther text")

        expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
        spechelp_check_mailto(
          html:    delivered.html,
          email:   "fred@example.com",
          subject: "Your Site Under Test booking enquiry"
        )
        spechelp_check_tel(
          html:  delivered.html,
          phone: '+64 021 000 000'
        )
        expect(delivered.html).to have_css("dt", text: "Date")
        expect(delivered.html).to have_css("dd", text: "20/01/#{Date.today.year + 2}")
        expect(delivered.html).to have_css("dt", text: "Preferred time")
        expect(delivered.html).to have_css("dd", text: "11:30")
        expect(delivered.html).to include(">Quick Brown Fox\n<br>Other text</p>")
      end
    end # 'context "enquiry form" do'
  end # 'context "viewing" do'
end
