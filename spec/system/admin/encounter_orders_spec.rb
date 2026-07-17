require "spec_helper.rb"
require_relative "../shared_contexts/encounter_order_context.rb"

RSpec.describe "Admin - encounter orders" do
  include_context "encounter orders"

  before :each do
    spechelp_log_in()

    @encounter = create(:encounter)
    @encounter.revisions.first.update!(published: true)
  end

  it "validates the form" do
    visit admin_encounters_path()

    click_on("Bookings") # (we expect only one row with that, for @encounter)
    click_on("Set up a new booking")
    click_on("Save booking")

    expect(page).to have_css(".field_error_messages", text: "Name must be provided")
    expect(page).to have_css(".field_error_messages", text: "E-mail address must be provided")
    expect(page).to have_css(".field_error_messages", text: "Number of people must be a positive whole number")

    fill_in("encounter_order_name", with: "Fred Flinstone")

    click_on("Save booking")

    expect(page).to     have_field("encounter_order_name", with: "Fred Flinstone")
    expect(page).to_not have_css(".field_error_messages", text: "Name must be provided")
    expect(page).to     have_css(".field_error_messages", text: "E-mail address must be provided")
    expect(page).to     have_css(".field_error_messages", text: "Number of people must be a positive whole number")

    fill_in("encounter_order_email", with: "fred@example.com")
    fill_in("encounter_order_number_of_seats", with: 2)

    click_on("Save booking")

    expect(page).to have_text("Encounter booking set up successfully")
  end

  it "can access booking set-up from encounter details" do
    visit admin_encounter_path(@encounter)

    expect(page).to have_text(@encounter.title)

    find(:css, "section.encounter-header").click_on("Set up a new booking")

    expect(page).to have_current_path(new_admin_encounter_encounter_order_path(encounter_id: @encounter.slug))
  end

  context "dynamic behaviour", js: true do
    context "form field interactions" do
      before :each do
        visit(new_admin_encounter_encounter_order_path(encounter_id: @encounter.slug))
      end

      it "start date/time" do
        expect(page).to have_field("encounter_order_starts_at", disabled: true)

        choose "Fixed:"

        expect(page).to have_field("encounter_order_starts_at", disabled: false)

        choose "Open-ended"

        expect(page).to have_field("encounter_order_starts_at", disabled: true)
      end

      it "physical product selection options" do
        expect(page).to have_css("#encounter_order_total_amount_hint", visible: true)

        hint = find(:css, "#encounter_order_total_amount_hint")
        physical_total = spechelp_format_money(@encounter.price_physical, @encounter.currency)

        expect(hint).to have_text("increased by #{physical_total}")

        select("Included", from: "encounter_order_has_physical")

        expect(page).to have_css("#encounter_order_total_amount_hint", visible: false)

        select("Customer chooses at checkout", from: "encounter_order_has_physical")

        expect(page).to have_css("#encounter_order_total_amount_hint", visible: true)

        select("Excluded", from: "encounter_order_has_physical")

        expect(page).to have_css("#encounter_order_total_amount_hint", visible: false)
      end

      it "totals" do
        fill_in("encounter_order_number_of_seats", with: "2")

        total = spechelp_format_money(
          @encounter.price_per_seat * 2,
          @encounter.currency,
          omit_symbol: true
        )

        expect(page).to have_field("encounter_order_amount_owed", with: total)

        select("Included", from: "encounter_order_has_physical")

        total = spechelp_format_money(
          @encounter.price_per_seat * 2 + @encounter.price_physical,
          @encounter.currency,
          omit_symbol: true
        )

        expect(page).to have_field("encounter_order_amount_owed", with: total)

        fill_in("encounter_order_number_of_seats", with: "")

        expect(page).to have_field("encounter_order_amount_owed", with: "")
      end
    end # 'context "form field interactions" do'

    context "form variants" do
      it "for a free-of-charge encounter" do
        encounter = create(:encounter, :free)
        visit(new_admin_encounter_encounter_order_path(encounter_id: encounter.slug))

        expect(page).to have_text("Free per seat")

        hint = find(:css, "#encounter_order_total_amount_hint")
        physical_total = spechelp_format_money(encounter.price_physical, encounter.currency)

        expect(hint).to have_text("increased by #{physical_total}")

        fill_in("encounter_order_number_of_seats", with: "2")
        select("Included", from: "encounter_order_has_physical")

        total = spechelp_format_money(
          encounter.price_physical,
          encounter.currency,
          omit_symbol: true
        )

        expect(page).to have_field("encounter_order_amount_owed", with: total)
      end

      it "with a free-of-charge physical product" do
        encounter = create(:encounter, :physical_free)
        visit(new_admin_encounter_encounter_order_path(encounter_id: encounter.slug))

        expect(page).to have_css("#encounter_order_total_amount_hint", visible: false)

        fill_in("encounter_order_number_of_seats", with: "2")
        select("Included", from: "encounter_order_has_physical")

        total = spechelp_format_money(
          encounter.price_per_seat * 2,
          encounter.currency,
          omit_symbol: true
        )

        expect(page).to have_field("encounter_order_amount_owed", with: total)
      end

      it "for a free-of-charge encounter with a free-of-charge physical product" do
        encounter = create(:encounter, :free, :physical_free)
        visit(new_admin_encounter_encounter_order_path(encounter_id: encounter.slug))

        expect(page).to have_text("Free per seat")
        expect(page).to have_css("#encounter_order_total_amount_hint", visible: false)

        fill_in("encounter_order_number_of_seats", with: "2")

        expect(page).to have_field("encounter_order_amount_owed", with: "0")
      end

      it "without a physical product" do
        encounter = create(:encounter, :physical_none)
        visit(new_admin_encounter_encounter_order_path(encounter_id: encounter.slug))

        expect(page).to_not have_field("encounter_order_has_physical")
        expect(page).to     have_text("This encounter has no related physical product")

        fill_in("encounter_order_number_of_seats", with: "2")

        total = spechelp_format_money(
          encounter.price_per_seat * 2,
          encounter.currency,
          omit_symbol: true
        )

        expect(page).to have_field("encounter_order_amount_owed", with: total)
      end

      it "for a free-of-charge encounter without a physical product" do
        encounter = create(:encounter, :free, :physical_none)
        visit(new_admin_encounter_encounter_order_path(encounter_id: encounter.slug))

        expect(page).to     have_text("Free per seat")
        expect(page).to_not have_field("encounter_order_has_physical")
        expect(page).to     have_text("This encounter has no related physical product")

        fill_in("encounter_order_number_of_seats", with: "2")

        expect(page).to have_field("encounter_order_amount_owed", with: "0")
      end

      context "optional line items" do
        it "are not offered for price-known (non-POA) encounters" do
          expect(@encounter.price_on_application?).to eql(false)
          visit(new_admin_encounter_encounter_order_path(encounter_id: @encounter.slug))

          expect(page).to have_text("Any other notes?")
          expect(page).to_not have_text("Optional itemisation for invoice")
        end

        it "can be added for POA encounters" do
          @encounter.update!(price_on_application: true)
          expect(@encounter.price_on_application?).to eql(true) # (self-check)
          visit(new_admin_encounter_encounter_order_path(encounter_id: @encounter.slug))

          expect(page).to have_text("Optional itemisation for invoice")

          # "Add item" should put focus into first new row; should be able to
          # type text for that, Tab to value, Enter for a new row.

          click_button "Add Item"

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 1)
          end

          spechelp_expect_focus_on(".encounter_order_item:nth-child(1) .encounter_order_item_description_field")

          field = spechelp_get_focused_element()
          field.send_keys("Item 1")
          field.send_keys(:tab) # Move to amount field

          spechelp_expect_focus_on(".encounter_order_item:nth-child(1) .encounter_order_item_amount_owed_field")

          field = spechelp_get_focused_element()
          field.send_keys("23")
          field.send_keys(:enter) # Add a new row and focus the description field

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 2)
          end

          spechelp_expect_focus_on(".encounter_order_item:nth-child(2) .encounter_order_item_description_field")

          field = spechelp_get_focused_element()
          field.send_keys("Item 2")
          field.send_keys(:tab)

          spechelp_expect_focus_on(".encounter_order_item:nth-child(2) .encounter_order_item_amount_owed_field")

          field = spechelp_get_focused_element()
          field.send_keys("11")

          # Check that totals are being updated
          #
          expect(find("#encounter_order_amount_owed").value).to eq("34") # (23 + 11)

          # A bit of drive-by extra coverage; we expect POA items to have chosen
          # "Other" as a default payment method and that'll require instructions,
          # so this should fail validation when we save it...
          #
          fill_in("encounter_order_name", with: "Fred Flinstone")
          fill_in("encounter_order_email", with: "fred@example.com")
          fill_in("encounter_order_number_of_seats", with: 2)

          click_on("Save booking")

          expect(page).to have_css("div.field_with_errors > textarea#encounter_order_supported_payment_method_other_details")
          expect(page).to have_text("Supported payment method other details must be provided")

          fill_in("encounter_order_supported_payment_method_other_details", with: "In exchange for some Burgandy")

          click_on("Save booking")

          expect(page).to have_text("Encounter booking set up successfully")

          expect(EncounterOrder.count).to eql(1)
          expect(EncounterOrder.first.name                                  ).to eql("Fred Flinstone")
          expect(EncounterOrder.first.email                                 ).to eql("fred@example.com")
          expect(EncounterOrder.first.number_of_seats                       ).to eql(2)
          expect(EncounterOrder.first.supported_payment_methods             ).to eql(["other"])
          expect(EncounterOrder.first.supported_payment_method_other_details).to eql("In exchange for some Burgandy")

          items = EncounterOrder.first.encounter_order_items.sort_by(&:description)

          expect(items.count).to eql(2)

          expect(items[0].description).to eql("Item 1")
          expect(items[0].amount_owed).to eql(23 * (10 ** Money::Currency.new(@encounter.currency).exponent))

          expect(items[1].description).to eql("Item 2")
          expect(items[1].amount_owed).to eql(11 * (10 ** Money::Currency.new(@encounter.currency).exponent))
        end

        it "must be validate, but empty rows are ignored" do
          @encounter.update!(price_on_application: true)
          expect(@encounter.price_on_application?).to eql(true) # (self-check)
          visit(new_admin_encounter_encounter_order_path(encounter_id: @encounter.slug))

          expect(page).to have_text("Optional itemisation for invoice")

          # "Add item" should put focus into first new row; should be able to
          # type text for that, Tab to value, Enter for a new row.

          click_button "Add Item"

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 1)
          end

          spechelp_expect_focus_on(".encounter_order_item:nth-child(1) .encounter_order_item_description_field")

          field = spechelp_get_focused_element()
          field.send_keys("Item 1")
          field.send_keys(:enter) # Drive-by test; Enter in the description field moves to the amount field

          spechelp_expect_focus_on(".encounter_order_item:nth-child(1) .encounter_order_item_amount_owed_field")

          field = spechelp_get_focused_element()
          field.send_keys(:enter) # Add a new row and focus the description field, before filling in amount

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 2)
          end

          spechelp_expect_focus_on(".encounter_order_item:nth-child(2) .encounter_order_item_description_field")

          field = spechelp_get_focused_element()
          field.send_keys(:tab) # Skip to the amount field, without filling in the description

          spechelp_expect_focus_on(".encounter_order_item:nth-child(2) .encounter_order_item_amount_owed_field")

          field = spechelp_get_focused_element()
          field.send_keys("11")

          fill_in("encounter_order_name", with: "Fred Flinstone")
          fill_in("encounter_order_email", with: "fred@example.com")
          fill_in("encounter_order_number_of_seats", with: 2)
          fill_in("encounter_order_supported_payment_method_other_details", with: "In exchange for some Burgandy")

          click_on("Save booking")

          expect(page).to have_css("div.field_with_errors > input#encounter_order_encounter_order_items_attributes_0_amount_owed")
          expect(page).to have_css("div.field_with_errors > input#encounter_order_encounter_order_items_attributes_1_description")

          # Fill in the missing information, and add a third row which we'll
          # leave blank. The "0/1" indexing only appears after saving the form;
          # JS row addition has to generate random unique negative IDs, so we
          # can't depend on those above.
          #
          fill_in("encounter_order_encounter_order_items_attributes_0_amount_owed", with: "23")
          fill_in("encounter_order_encounter_order_items_attributes_1_description", with: "Item 2")
          click_on("Add Item")

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 3)
          end

          click_on("Save booking")

          # No validation issues from that blank row
          #
          expect(page).to have_text("Encounter booking set up successfully")

          expect(EncounterOrder.count).to eql(1)
          expect(EncounterOrder.first.name                                  ).to eql("Fred Flinstone")
          expect(EncounterOrder.first.email                                 ).to eql("fred@example.com")
          expect(EncounterOrder.first.number_of_seats                       ).to eql(2)
          expect(EncounterOrder.first.supported_payment_methods             ).to eql(["other"])
          expect(EncounterOrder.first.supported_payment_method_other_details).to eql("In exchange for some Burgandy")

          items = EncounterOrder.first.encounter_order_items.sort_by(&:description)

          expect(items.count).to eql(2) # Not 3 - the blank row was ignored

          expect(items[0].description).to eql("Item 1")
          expect(items[0].amount_owed).to eql(23 * (10 ** Money::Currency.new(@encounter.currency).exponent))

          expect(items[1].description).to eql("Item 2")
          expect(items[1].amount_owed).to eql(11 * (10 ** Money::Currency.new(@encounter.currency).exponent))
        end

        it "hides/shows extra payment instructions and allows amendments to line items" do
          @encounter.update!(price_on_application: true)
          expect(@encounter.price_on_application?).to eql(true) # (self-check)
          visit(new_admin_encounter_encounter_order_path(encounter_id: @encounter.slug))

          expect(page).to have_text("Optional itemisation for invoice")

          # A bit of drive-by extra coverage; we expect POA items to have chosen
          # "Other" as a default payment method and that'll require instructions,
          # so this should fail validation when we save it...
          #
          fill_in("encounter_order_name", with: "Fred Flinstone")
          fill_in("encounter_order_email", with: "fred@example.com")
          fill_in("encounter_order_number_of_seats", with: 2)
          fill_in("encounter_order_supported_payment_method_other_details", with: "In exchange for some Burgandy")

          click_on("Add Item")

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 1)
          end

          click_on("Add Item")

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 2)
          end

          #encounter_order_items_wrapper

          find("#encounter_order_items_wrapper .encounter_order_item:nth-child(1) input.encounter_order_item_description_field").set("Item 1")
          find("#encounter_order_items_wrapper .encounter_order_item:nth-child(1) input.encounter_order_item_amount_owed_field").set("24")
          find("#encounter_order_items_wrapper .encounter_order_item:nth-child(2) input.encounter_order_item_description_field").set("Item 2")
          find("#encounter_order_items_wrapper .encounter_order_item:nth-child(2) input.encounter_order_item_amount_owed_field").set("15")

          expect(find("#encounter_order_amount_owed").value).to eq("39") # (24 + 15)

          check("encounter_order_supported_payment_methods_stripe")
          uncheck("encounter_order_supported_payment_methods_other")

          expect(page).to_not have_css("#encounter_order_supported_payment_method_other_details")

          check("encounter_order_supported_payment_methods_other")

          expect(page).to have_css("#encounter_order_supported_payment_method_other_details")

          click_on("Save booking")

          expect(page).to have_text("Encounter booking set up successfully")

          expect(EncounterOrder.count).to eql(1)
          expect(EncounterOrder.first.name                                  ).to eql("Fred Flinstone")
          expect(EncounterOrder.first.email                                 ).to eql("fred@example.com")
          expect(EncounterOrder.first.number_of_seats                       ).to eql(2)
          expect(EncounterOrder.first.supported_payment_methods             ).to match_array(["other", "stripe"])
          expect(EncounterOrder.first.supported_payment_method_other_details).to eql("In exchange for some Burgandy")

          items = EncounterOrder.first.encounter_order_items.sort_by(&:description)

          expect(items.count).to eql(2)

          expect(items[0].description).to eql("Item 1")
          expect(items[0].amount_owed).to eql(24 * (10 ** Money::Currency.new(@encounter.currency).exponent))

          expect(items[1].description).to eql("Item 2")
          expect(items[1].amount_owed).to eql(15 * (10 ** Money::Currency.new(@encounter.currency).exponent))

          # Try some small amendments

          click_on("Amend booking")

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 2)
          end

          # *Third* child, as on edit, a hidden form field ends up at child index 2 & 4
          find("#encounter_order_items_wrapper .encounter_order_item:nth-child(3) input.encounter_order_item_amount_owed_field").set("11")

          expect(find("#encounter_order_amount_owed").value).to eq("35") # (24 + 11)

          click_on("Add Item")

          within "#encounter_order_items_wrapper" do
            expect(page).to have_css(".encounter_order_item", count: 3)
          end

          # *Fifth* child, as on edit, a hidden form field ends up at child index 2 & 4
          find("#encounter_order_items_wrapper .encounter_order_item:nth-child(5) input.encounter_order_item_description_field").set("Item 3")
          find("#encounter_order_items_wrapper .encounter_order_item:nth-child(5) input.encounter_order_item_amount_owed_field").set("41")

          expect(find("#encounter_order_amount_owed").value).to eq("76") # (24 + 11 + 41)

          click_on("Save Amendments")
          spechelp_check_flash(:notice, "Booking successfully amended")

          items = EncounterOrder.first.encounter_order_items.sort_by(&:description)

          expect(items.count).to eql(3)

          expect(items[0].description).to eql("Item 1")
          expect(items[0].amount_owed).to eql(24 * (10 ** Money::Currency.new(@encounter.currency).exponent))

          expect(items[1].description).to eql("Item 2")
          expect(items[1].amount_owed).to eql(11 * (10 ** Money::Currency.new(@encounter.currency).exponent))

          expect(items[2].description).to eql("Item 3")
          expect(items[2].amount_owed).to eql(41 * (10 ** Money::Currency.new(@encounter.currency).exponent))
        end
      end # 'context "optional line items" do'
    end # 'context "form variants" do'
  end # 'context "dynamic behaviour", js: true do'

  # An encounter is set up because someone sends an enquiry. The admin sets up
  # the booking (creates an EncounterOrder) and it makes sense for them to mail
  # that back manually rather than have a less personal, automated message
  # which might surprise the end user.
  #
  # That's why these tests check for a mail delivery count of zero.
  #
  shared_examples "an order creator" do
    it "which creates and lets the admin contact the user" do
      visit(new_admin_encounter_encounter_order_path(encounter_id: @encounter.slug))

      name   = "Fred Flintstone"
      email  = "fred@example.com"
      phone  = "+64 021 000 000"
      seats  = 2
      notes  = "The quick brown fox"
      starts = (Time.current + 1.day).midnight + 18.hours

      fill_in("encounter_order_name",            with: name)
      fill_in("encounter_order_email",           with: email)
      fill_in("encounter_order_phone_number",    with: phone)
      fill_in("encounter_order_number_of_seats", with: seats)
      fill_in("encounter_order_starts_at",       with: starts.iso8601)
      fill_in("encounter_order_notes_to_buyer",  with: notes)
      select("Included", from: "encounter_order_has_physical")

      click_on("Save booking")

      expect(page).to have_text("Encounter booking set up successfully")

      expected_state, expected_total = if EncounterOrder.first.amount_owed.zero?
        expect(page).to have_button("Invoice")
        ["paid", "No charge"]
      else
        expect(page).to have_button("Mark as 'paid'")
        expect(page).to have_button("Cancel order")
        ["new", spechelp_format_money(EncounterOrder.first.amount_owed, @encounter.currency)]
      end

      expect(EncounterOrder.count).to eql(1)
      expect(EncounterOrder.first.state          ).to eql(expected_state)
      expect(EncounterOrder.first.name           ).to eql(name)
      expect(EncounterOrder.first.email          ).to eql(email)
      expect(EncounterOrder.first.phone_number   ).to eql("021 000 000")
      expect(EncounterOrder.first.number_of_seats).to eql(seats)
      expect(EncounterOrder.first.amount_owed    ).to eql(2 * @encounter.price_per_seat + @encounter.price_physical)
      expect(EncounterOrder.first.starts_at      ).to eql(starts)

      expect(ActionMailer::Base.deliveries.count).to eq(0)

      expect(page).to have_text(expected_total)
      expect(page).to have_text(encordshelp_share_link(EncounterOrder.first))
      expect(page).to have_text(encordshelp_magic_link(EncounterOrder.first))
    end
  end

  context "free events" do
    before :each do
      @encounter.update!(price_per_seat: 0, price_physical: 0)
    end

    it_behaves_like "an order creator"

    # The controller would normally set a paid-state for zero amount EOs, but
    # to save time-in-test, that's just set manually here.
    #
    it "can view the invoice" do
      eo = create(:encounter_order, encounter: @encounter, state: "paid")

      visit(admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: eo.id))

      expect(page).to have_button("Invoice")
      click_on("Invoice")

      total = spechelp_format_money(0, @encounter.currency)

      expect(page).to have_text(eo.human_invoice_number)
      expect(page).to have_text(eo.name)
      expect(page).to have_text(eo.email)
      expect(page).to have_text(eo.address)
      expect(page).to have_text(@encounter.title)
      expect(page).to have_text(total)
      expect(page).to have_text("PAID IN FULL")
    end
  end

  context "paid events" do
    it_behaves_like "an order creator"

    context "before being paid for" do
      before :each do
        @encounter_order = create(:encounter_order, encounter: @encounter)
        visit(admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: @encounter_order.id))
      end

      it "cannot view an invoice" do
        expect(page).to_not have_button("Invoice")
      end

      it "can be manually marked as 'paid'" do
        click_on("Mark as 'paid'")
        spechelp_check_flash(:notice, "Booking updated")

        @encounter_order.reload()

        expect(@encounter_order.state).to eql("paid")
        verify_upon_payment_emails(@encounter_order)

        # A Some extended tests - check the "magic" link works and the user can
        # reach the invoice; this probably duplicates some test coverage from
        # other angles, but doesn't hurt to include anyway.

        visit URI(encordshelp_magic_link(@encounter_order)).path

        expect(page).to     have_text("Manage booking")
        expect(page).to     have_text("Gift link")
        expect(page).to     have_text(encordshelp_share_link(@encounter_order))
        expect(page).to_not have_text(encordshelp_magic_link(@encounter_order))
        expect(page).to     have_text("The booking has been paid for")
        expect(page).to     have_text("If you think you need to cancel and request a refund, please contact us")
        expect(page).to_not have_button("Cancel")
        expect(page).to     have_link("Invoice")

        click_on("Invoice")

        expect(page).to have_text(@encounter_order.human_invoice_number)

        # Likewise, include a very quick check of the "share" link.

        @encounter_order.update_column(:gift_note, "Extra test coverage")

        visit URI(encordshelp_share_link(@encounter_order)).path

        expect(page).to have_text(@encounter.title)
        expect(page).to have_text("Extra test coverage")
        expect(page).to have_text(@encounter.location)
        expect(page).to have_text(encordshelp_datetime(@encounter_order))
      end

      it "can be amended" do
        click_on("Amend booking")

        old_seats = @encounter_order.number_of_seats
        new_seats = old_seats + 1

        fill_in("encounter_order_number_of_seats", with: new_seats)

        click_on("Save Amendments")
        spechelp_check_flash(:notice, "Booking successfully amended")

        @encounter_order.reload

        expect(@encounter_order.number_of_seats).to eql(new_seats)
      end

      it "can be cancelled" do
        click_on("Cancel")
        spechelp_check_flash(:notice, "Booking updated")

        @encounter_order.reload()

        expect(@encounter_order.state).to eql("cancelled")

        to_customer = spechelp_decode_multipart()

        expect(to_customer.email.to     ).to eql([@encounter_order.email])
        expect(to_customer.email.from   ).to eql(["orders@example.com"])
        expect(to_customer.email.subject).to eql("Confirmation of cancellation for \"#{@encounter_order.encounter.title}\"")

        expect(to_customer.text).to include(@encounter_order.encounter.title.upcase)
        expect(to_customer.text).to include("Your booking has been cancelled")

        expect(to_customer.html).to include(@encounter_order.encounter.title)
        expect(to_customer.html).to include("Your booking has been cancelled")
      end
    end # 'context "before being paid for" do'

    context "after being paid for" do
      it "can view the invoice" do
        eo = create(:encounter_order, encounter: @encounter)
        eo.pay_state!

        visit(admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: eo.id))

        expect(page).to have_button("Invoice")
        click_on("Invoice")

        total = spechelp_format_money(eo.amount_owed, @encounter.currency)

        expect(page).to have_text(eo.human_invoice_number)
        expect(page).to have_text(eo.name)
        expect(page).to have_text(eo.email)
        expect(page).to have_text(eo.address)
        expect(page).to have_text(@encounter.title)
        expect(page).to have_text(total)
        expect(page).to have_text("PAID IN FULL")
      end

      it "can be manually refunded" do
        eo = create(:encounter_order, encounter: @encounter)
        eo.pay_state! # It'll have no Stripe payment references

        perform_enqueued_jobs()
        ActionMailer::Base.deliveries.clear()

        visit(admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: eo.id))

        click_on("Refund customer (process manually)")

        verify_upon_refund_email(eo)
      end

      # For a bit of extra (intentionally overlapping) coverage, this is done
      # via a full Stripe mock setup as if the user completed checkout; that
      # way we can check that 'full' refunds work.
      #
      it "can be automatically refunded" do
        eo = create(:encounter_order, encounter: @encounter)

        visit URI(encordshelp_magic_link(eo)).path

        per_seat = spechelp_format_money(@encounter.price_per_seat, @encounter.currency)
        physical = spechelp_format_money(@encounter.price_physical, @encounter.currency)
        total    = spechelp_format_money(eo.amount_owed,            @encounter.currency)

        expect(page).to have_text("Manage booking for")
        expect(page).to have_text(@encounter.title)
        expect(page).to have_text(encordshelp_datetime(eo))
        expect(page).to have_text(eo.name)
        expect(page).to have_text(eo.email)
        expect(page).to have_text("#{eo.number_of_seats} → #{total}")
        expect(page).to have_text("#{total}")

        check("encounter_order_has_physical")
        fill_in("encounter_order_gift_note", with: "Extra test coverage")

        mock_payint = simulate_stripe_payment(eo)

        visit(admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: eo.id))

        expect(Stripe::Refund).to receive(:create).with(payment_intent: mock_payint).and_return(double(status: "succeeded"))

        click_on("Refund customer (automatic via Stripe)")

        eo.reload

        expect(eo.state).to eql("refunded")
        verify_upon_refund_email(eo)
      end

      # Consider, for example, double-form submission despite button debounce.
      #
      it "handles the edge case of somehow the order not being in an updateable state" do
        eo = create(:encounter_order, encounter: @encounter)
        visit URI(encordshelp_magic_link(eo)).path

        expect(page).to have_text("Manage booking for")

        mock_payint = simulate_stripe_payment(eo)
        visit(admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: eo.id))

        # Force a refund via driving state directly, while the encounter order
        # admin page is still open.
        #
        expect(Stripe::Refund).to receive(:create).with(payment_intent: mock_payint).and_return(double(status: "succeeded"))

        eo.refund_state!

        # If the admin now tries to refund via the UI, we shouldn't get any
        # attempt to refund again.
        #
        expect(Stripe::Refund).to_not receive(:create)

        click_on("Refund customer (automatic via Stripe)")

        expect(page).to have_text("That booking cannot be changed in that way")
      end
    end # 'context "after being paid for" do'

    context "if payment fails" do
      it "can be cancelled" do
        eo = create(:encounter_order, encounter: @encounter)
        eo.payment_failed_state!

        to_customer = spechelp_decode_multipart()
        total       = spechelp_format_money(eo.amount_owed, @encounter.currency)

        expect(to_customer.email.to     ).to eql([eo.email])
        expect(to_customer.email.from   ).to eql(["orders@example.com"])
        expect(to_customer.email.subject).to eql("Payment failure for \"#{eo.encounter.title}\"")

        expect(to_customer.text).to include(eo.encounter.title.upcase)
        expect(to_customer.text).to include("there was a problem with your payment")
        expect(to_customer.text).to include(total)

        expect(to_customer.html).to include(eo.encounter.title)
        expect(to_customer.html).to include("there was a problem with your payment")
        expect(to_customer.html).to include(total)

        ActionMailer::Base.deliveries.clear()
        visit(admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: eo.id))

        click_on("Cancel")
        spechelp_check_flash(:notice, "Booking updated")

        eo.reload()

        expect(eo.state).to eql("cancelled")

        messages    = spechelp_decode_multipart(count: 2)
        to_customer = spechelper_find_in_decoded(messages, to: eo.email)
        to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

        expect(to_customer.email.from   ).to eql(["orders@example.com"])
        expect(to_customer.email.subject).to eql("Confirmation of cancellation for \"#{eo.encounter.title}\"")

        expect(to_customer.text).to include(eo.encounter.title.upcase)
        expect(to_customer.text).to include("Your booking has been cancelled")

        expect(to_customer.html).to include(eo.encounter.title)
        expect(to_customer.html).to include("Your booking has been cancelled")

        expect(to_admin.email.from   ).to eql(["orders@example.com"])
        expect(to_admin.email.subject).to eql("[Site Under Test] Encounter cancellation from #{eo.name}")

        expect(to_admin.text).to include(eo.name)
        expect(to_admin.text).to include(eo.email)
        expect(to_admin.text).to include(eo.phone_number)

        expect(to_admin.html).to have_css("dd", text: eo.name)
        expect(to_admin.html).to have_css("dd", text: eo.number_of_seats)
        spechelp_check_mailto(
          html:    to_admin.html,
          email:   eo.email,
          subject: "Your booking for \"#{@encounter.title}\""
        )
        spechelp_check_tel(
          html:  to_admin.html,
          phone: eo.phone_number
        )
        expect(to_admin.html).to have_link(
          "Manage booking",
          href: admin_encounter_encounter_order_url(encounter_id: @encounter.slug, id: eo.id)
        )
        expect(to_admin.html).to have_link(
          "here", # ...as in, "You can find a list of all encounter bookings <here>"
          href: admin_encounter_encounter_orders_url(encounter_id: @encounter.slug)
        )
      end
    end # 'context "if payment fails" do'
  end # 'context "paid events" do'
end
