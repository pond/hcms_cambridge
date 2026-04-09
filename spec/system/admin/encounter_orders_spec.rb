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
    click_on("Save and send")

    expect(page).to have_css(".field_error_messages", text: "Name must be provided")
    expect(page).to have_css(".field_error_messages", text: "E-mail address must be provided")
    expect(page).to have_css(".field_error_messages", text: "Number of people must be greater than 0")

    fill_in("encounter_order_name", with: "Fred Flinstone")

    click_on("Save and send")

    expect(page).to     have_field("encounter_order_name", with: "Fred Flinstone")
    expect(page).to_not have_css(".field_error_messages", text: "Name must be provided")
    expect(page).to     have_css(".field_error_messages", text: "E-mail address must be provided")
    expect(page).to     have_css(".field_error_messages", text: "Number of people must be greater than 0")

    fill_in("encounter_order_email", with: "fred@example.com")
    fill_in("encounter_order_number_of_seats", with: 2)

    click_on("Save and send")

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

      click_on("Save and send")

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
