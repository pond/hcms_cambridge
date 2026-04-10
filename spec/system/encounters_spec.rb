require "spec_helper.rb"
require_relative "shared_examples/footer_spec.rb"

RSpec.describe "Encounters" do
  include ApplicationHelper

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

    it "shows correct event pricing" do
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
        link    = "mailto:#{Hcms.config.contact_email}?subject=#{ERB::Util.url_encode(encounter.title)}"
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
        expect(details).to have_link("Enquire", href: link)

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
      end
    end
  end # 'context "viewing" do'
end
