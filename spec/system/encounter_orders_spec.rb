require "spec_helper.rb"
require_relative "shared_contexts/encounter_order_context.rb"

RSpec.describe "Admin - encounter orders" do
  include_context "encounter orders"

  before :each do
    @encounter = create(:encounter)
    @encounter.revisions.first.update!(published: true)
  end

  context "making payment" do
    shared_examples "an encounter booking confirmation form" do | select_physical = nil |
      before :each do
        visit(encordshelp_magic_link(@encounter_order))
      end

      it "which has the expected text and fields" do
        expect(page).to have_text("Manage booking for")
        expect(page).to have_text(@encounter.title)
        expect(page).to have_text(encordshelp_datetime(@encounter_order))
        expect(page).to have_text("#{@encounter_order.number_of_seats} →")

        if @encounter_order.amount_owed.zero?
          expect(page).to have_text("→ No charge")
        else
          expect(page).to have_text("→ #{apphelp_money(@encounter_order.amount_owed, currency: @encounter.currency)}")
        end

        physical = if @encounter.physical_aspect_free_of_charge?
          "(including free #{@encounter.name_physical})"
        else
          "(including #{apphelp_money(@encounter.price_physical, currency: @encounter.currency)} for #{@encounter.name_physical})"
        end

        if @encounter_order.has_physical
          expect(page).to have_text(physical)
        else
          expect(page).to_not have_text(physical)
        end

        expect(page).to have_field("encounter_order_gift_note")

        if @encounter.has_physical_aspect? and @encounter_order.user_chooses_has_physical
          expect(page).to have_unchecked_field("encounter_order_has_physical")
          label = page.find(:css, "label[for='encounter_order_has_physical']")
          if @encounter.physical_aspect_free_of_charge?
            expect(label).to have_text("Include free #{@encounter.name_physical}?")
          else
            expect(label).to have_text("Add #{@encounter.name_physical} for #{apphelp_money(@encounter.price_physical, currency: @encounter.currency)}?")
          end
        else
          expect(page).to_not have_field("encounter_order_has_physical")
        end

        if select_physical == true
          check("encounter_order_has_physical")
        elsif select_physical == false
          uncheck("encounter_order_has_physical")
        end
      end

      context "which lets the user pay" do
        before :each do
          visit(encordshelp_magic_link(@encounter_order))

          @gift_note = [SecureRandom.uuid, nil].sample()

          unless @gift_note.nil?
            fill_in("encounter_order_gift_note", with: @gift_note)
          end
        end

        it "and finalises the booking" do
          simulate_stripe_payment(@encounter_order)
        end
      end # 'context "which lets the user pay" do'
    end # 'shared_examples "an encounter booking confirmation form" do'

    context "user chooses physical product" do
      context "physical product is free" do
        before :each do
          @encounter.update!(price_physical: 0)
          @encounter_order = create(:encounter_order, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(true)
          expect(@encounter_order.user_chooses_has_physical).to eql(true)
          expect(@encounter_order.has_physical             ).to eql(false)
        end

        it_behaves_like "an encounter booking confirmation form", select_physical: true
        it_behaves_like "an encounter booking confirmation form", select_physical: false
      end # 'context "physical product is free" do'

      context "physical product must be paid for" do
        before :each do
          @encounter_order = create(:encounter_order, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(true)
          expect(@encounter_order.has_physical             ).to eql(false)
        end

        it_behaves_like "an encounter booking confirmation form", select_physical: true
        it_behaves_like "an encounter booking confirmation form", select_physical: false
      end # 'context "physical product must be paid for" do'

      # Bad/unexpected data edge case check.
      #
      context "but the encounter offers no physical product" do
        before :each do
          @encounter.update!(price_physical: nil)
          @encounter_order = create(:encounter_order, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(false)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(true)
          expect(@encounter_order.has_physical             ).to eql(false)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "but the encounter offers no physical product" do'
    end # 'context "user chooses physical product" do'

    context "with a physical product" do
      context "physical product is free" do
        before :each do
          @encounter.update!(price_physical: 0)
          @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(true)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "physical product is free" do'

      context "physical product must be paid for" do
        before :each do
          @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "physical product must be paid for" do'

      # Bad/unexpected data edge case check.
      #
      context "but the encounter offers no physical product" do
        before :each do
          @encounter.update!(price_physical: nil)
          @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(false)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "but the encounter offers no physical product" do'
    end # 'context "with a physical product" do'

    context "without a physical product" do
      before :each do
        @encounter_order = create(:encounter_order, :no_physical, encounter: @encounter)

        expect(@encounter.has_physical_aspect?           ).to eql(true)
        expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
        expect(@encounter_order.user_chooses_has_physical).to eql(false)
        expect(@encounter_order.has_physical             ).to eql(false)
      end

      it_behaves_like "an encounter booking confirmation form"
    end # 'context "without a physical product" do'

    context "when the seats are free" do
      before :each do
        @encounter.update!(price_per_seat: 0)

        expect(@encounter.free_of_charge?     ).to eql(true)
        expect(@encounter.has_physical_aspect?).to eql(true)
      end

      context "but the physical product is not" do
        before :each do
          @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "but the physical product is not" do'

      context "and the physical product is also free" do
        before :each do
          @encounter.update!(price_physical: 0)
          @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(true)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "and the physical product is also free" do'

      context "and no physical product is offered" do
        before :each do
          @encounter.update!(price_physical: nil)
          @encounter_order = create(:encounter_order, :no_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(false)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(false)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "and no physical product is offered" do'
    end # 'context "when the seats are free" do'

    context "with a discount" do
      context "and when the can user choose to add a physical product" do
        before :each do
          @encounter_order = create(:encounter_order, :discounted, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(true)
          expect(@encounter_order.has_physical             ).to eql(false)
          expect(@encounter_order.includes_discount?       ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form", select_physical: true
        it_behaves_like "an encounter booking confirmation form", select_physical: false
      end # 'context "and a physical product excluded" do'

      context "and a physical product included" do
        before :each do
          @encounter_order = create(:encounter_order, :discounted, :has_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(true)
          expect(@encounter_order.includes_discount?       ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "and a physical product included" do'

      context "and a physical product excluded" do
        before :each do
          @encounter_order = create(:encounter_order, :discounted, :no_physical, encounter: @encounter)

          expect(@encounter.has_physical_aspect?           ).to eql(true)
          expect(@encounter.physical_aspect_free_of_charge?).to eql(false)
          expect(@encounter_order.user_chooses_has_physical).to eql(false)
          expect(@encounter_order.has_physical             ).to eql(false)
          expect(@encounter_order.includes_discount?       ).to eql(true)
        end

        it_behaves_like "an encounter booking confirmation form"
      end # 'context "and a physical product excluded" do'
    end # 'context "with a discount" do'
  end # "context "making payment" do"

  context "after payment" do
    context "priced by seat" do
      before :each do
        @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)
        visit(encordshelp_magic_link(@encounter_order))
        simulate_stripe_payment(@encounter_order)
      end

      it "lets the user view their booking" do
        visit(encordshelp_magic_link(@encounter_order))

        expect(page).to have_text(@encounter.title)
        expect(page).to have_text(apphelp_money(@encounter_order.amount_owed, currency: @encounter.currency))
        expect(page).to have_text(encordshelp_datetime(@encounter_order))
        expect(page).to have_text(encordshelp_share_link(@encounter_order))
        expect(page).to have_text("The booking has been paid for successfully")
      end

      it "lets the user view an invoice" do
        visit(encordshelp_magic_link(@encounter_order))
        click_on("Invoice")

        seats = spechelp_format_money(@encounter_order.frozen_price_per_seat, @encounter.currency)
        items = spechelp_format_money(@encounter_order.frozen_price_physical, @encounter.currency)
        total = spechelp_format_money(@encounter_order.amount_owed,           @encounter.currency)

        expect(page).to     have_text(@encounter.title)
        expect(page).to     have_text(@encounter_order.human_invoice_number)
        expect(page).to     have_text(@encounter_order.name)
        expect(page).to     have_text(@encounter_order.email)
        expect(page).to     have_text(@encounter_order.address)

        expect(page).to_not have_text("Special price")
        expect(page).to     have_text(seats)
        expect(page).to     have_text(items)
        expect(page).to     have_text(total)

        expect(page).to     have_text("PAID IN FULL")
      end

      it "does not change even if the encounter price is altered" do
        visit(encordshelp_magic_link(@encounter_order))

        @encounter.update!(
          price_per_seat: @encounter.price_per_seat * 2,
          price_physical: @encounter.price_physical * 2
        )

        click_on("Invoice")

        seats = spechelp_format_money(@encounter_order.frozen_price_per_seat, @encounter.currency)
        items = spechelp_format_money(@encounter_order.frozen_price_physical, @encounter.currency)
        total = spechelp_format_money(@encounter_order.amount_owed,           @encounter.currency)

        expect(page).to     have_text(@encounter.title)

        expect(page).to     have_text(@encounter_order.human_invoice_number)
        expect(page).to     have_text(@encounter_order.name)
        expect(page).to     have_text(@encounter_order.email)
        expect(page).to     have_text(@encounter_order.address)

        expect(page).to_not have_text("Special price")
        expect(page).to     have_text(seats)
        expect(page).to     have_text(items)
        expect(page).to     have_text(total)

        expect(page).to     have_text("PAID IN FULL")
      end

      it "shows discounts" do
        visit(encordshelp_magic_link(@encounter_order))

        @encounter_order.update!(amount_owed: @encounter_order.amount_owed / 2)

        click_on("Invoice")

        seats = spechelp_format_money(@encounter_order.frozen_price_per_seat, @encounter.currency)
        items = spechelp_format_money(@encounter_order.frozen_price_physical, @encounter.currency)
        total = spechelp_format_money(@encounter_order.amount_owed,           @encounter.currency)

        expect(page).to     have_text(@encounter.title)
        expect(page).to     have_text(@encounter_order.human_invoice_number)
        expect(page).to     have_text(@encounter_order.name)
        expect(page).to     have_text(@encounter_order.email)
        expect(page).to     have_text(@encounter_order.address)

        expect(page).to     have_text("Special price")
        expect(page).to_not have_text(seats)
        expect(page).to     have_text(items)
        expect(page).to     have_text(total)

        expect(page).to     have_text("PAID IN FULL")
      end

      it "lets a giftee view encounter details, with no prices shown" do
        visit(encordshelp_share_link(@encounter_order))

        expect(page).to     have_text(@encounter.title)
        expect(page).to     have_text(@encounter_order.gift_note)
        expect(page).to     have_text(encordshelp_datetime(@encounter_order))
        expect(page).to     have_text(spechelp_strip_markup @encounter.body)

        expect(page).to_not have_text(apphelp_money(@encounter_order.amount_owed, currency: @encounter.currency))
        expect(page).to_not have_text(Money.new(0, @encounter.currency).symbol)
        expect(page).to_not have_text(encordshelp_share_link(@encounter_order))
        expect(page).to_not have_text("The booking has been paid for successfully")
      end
    end # 'context "priced by seat" do'

    context "price-on-application" do
      before :each do
        @encounter.update!(price_on_application: true)
        @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)
        @encounter_order.update!(amount_owed: rand(11111..99999))
        visit(encordshelp_magic_link(@encounter_order))
        simulate_stripe_payment(@encounter_order)
      end

      shared_examples "a price-on-application invoice" do
        it "which shows the custom amount" do
          seats = spechelp_format_money(@encounter_order.frozen_price_per_seat, @encounter.currency)
          items = spechelp_format_money(@encounter_order.frozen_price_physical, @encounter.currency)
          total = spechelp_format_money(@encounter_order.amount_owed,           @encounter.currency)

          expect(page).to     have_text(@encounter.title)
          expect(page).to     have_text(@encounter_order.human_invoice_number)
          expect(page).to     have_text(@encounter_order.name)
          expect(page).to     have_text(@encounter_order.email)
          expect(page).to     have_text(@encounter_order.address)

          expect(page).to     have_text("Custom price")
          expect(page).to_not have_text(seats)
          expect(page).to_not have_text(items)
          expect(page).to     have_text(total)

          expect(page).to     have_text("PAID IN FULL")
        end
      end

      context "when the encounter record remains unchanged" do
        before :each do
          click_on("Invoice")
        end

        it_behaves_like "a price-on-application invoice"
      end # 'context "when the encounter record remains unchanged" do'

      context "when the encounter record POA flag is later cleared" do
        before :each do
          @encounter.update!(price_on_application: false)
          expect(@encounter.price_per_seat).to_not be_zero # (self-check of prior factory setup)
          click_on("Invoice")
        end

        it_behaves_like "a price-on-application invoice"
      end # 'context "when the encounter record POA flag is later cleared" do'
    end # 'context "price-on-application" do'
  end # 'context "after payment" do'"

  context "unusual workflows" do
    before :each do
      @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)

      # Some tests cause a redirection back to the root path - so there needs to
      # *be* a root path!
      #
      create(:page).revisions.first.update!(published: true)

      visit(encordshelp_magic_link(@encounter_order))
    end

    it "handles the user cancelling from within Stripe and confirming" do
      mock_prodid  = "product_test_1234"
      mock_priceid = "price_test_1234"
      mock_csid    = "cs_test_1234"

      expect(Stripe::Product).to receive(:create).once do | args |
        double(id: mock_prodid)
      end

      expect(Stripe::Price).to receive(:create).once do | args |
        double(id: mock_priceid)
      end

      expect(Stripe::Checkout::Session).to receive(:create).once do | args |
        double(url: args[:cancel_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
      end

      click_on("Pay now")

      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("new")
      expect(page).to have_text("Please confirm cancellation")

      click_on("Cancel")

      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("cancelled")
      expect(page).to have_text("OK, that's cancelled")
      expect(page).to have_current_path(root_path())
    end

    it "handles the user cancelling from within Stripe but then changing their mind and paying" do
      mock_prodid  = "product_test_1234"
      mock_priceid = "price_test_1234"
      mock_csid    = "cs_test_1234"
      mock_payint  = "pi_test_1234"

      expect(Stripe::Product).to receive(:create).once do | args |
        double(id: mock_prodid)
      end

      expect(Stripe::Price).to receive(:create).once do | args |
        double(id: mock_priceid)
      end

      expect(Stripe::Checkout::Session).to receive(:create).once do | args |
        double(url: args[:cancel_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
      end

      click_on("Pay now")

      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("new")
      expect(page).to have_text("Please confirm cancellation")

      expect(Stripe::Checkout::Session).to receive(:create).once do | args |
        double(url: args[:success_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
      end

      expect(Stripe::Checkout::Session).to receive(:retrieve).with(mock_csid) do
        double(payment_intent: mock_payint)
      end

      click_on("Pay now")

      expect(page).to have_text("Thanks, your encounter booking is confirmed")
      expect(page).to have_current_path(encordshelp_magic_link(@encounter_order))
      expect(StripePrice.count).to eql(1)
      expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
      expect(StripePayment.count).to eql(1)
      expect(StripePayment.first.stripe_payment_intent).to eql(mock_payint)
      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("paid")

      messages    = spechelp_decode_multipart(count: 2)
      to_customer = spechelper_find_in_decoded(messages, to: @encounter_order.email)
      to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

      expect(to_customer).to be_present
      expect(to_admin   ).to be_present
    end
  end # 'context "unusual workflows" do'

  context "handling failures" do
    before :each do
      @encounter_order = create(:encounter_order, :has_physical, encounter: @encounter)
      visit(encordshelp_magic_link(@encounter_order))
    end

    # This is probably the most serious of all error cases, since it means
    # that "our side" has not recorded payment but money has almost
    # certainly been taken from the customer by Stripe.
    #
    it "of on-success attempt to update order state" do
      mock_prodid  = "product_test_1234"
      mock_priceid = "price_test_1234"
      mock_csid    = "cs_test_1234"

      expect(Stripe::Product).to receive(:create).once do | args |
        double(id: mock_prodid)
      end

      expect(Stripe::Price).to receive(:create).once do | args |
        double(id: mock_priceid)
      end

      expect(Stripe::Checkout::Session).to receive(:create).once do | args |
        double(url: args[:success_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
      end

      expect(EncounterOrder).to receive(:lock) { raise "An error" }

      captured_message = nil

      expect(Sentry).to receive(:capture_exception).with(kind_of(RuntimeError), extra: { encounter_order_id: @encounter_order.id })
      expect(Sentry).to receive(:capture_message) do | message, **args |
        captured_message = message
        expect(message).to include("Payment made but website-side encounter order update failed")
        encounter_order_id = args[:extra][:encounter_order_id]
        expect(@encounter_order.id).to eql(encounter_order_id)
        expect(captured_message).to include(encounter_order_id)
      end

      click_on("Pay now")

      expect(StripePrice.count).to eql(1)
      expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
      expect(StripePayment.count).to eql(0)
      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("new") # :-(
      expect(captured_message).to include(@encounter_order.id) # Proves that by this point, it's still the same EO

      # We *don't tell the customer* since our best guess is that Stripe
      # did succeed, since it invoked the on-success URL. This is our mess
      # to sort out, so we're mostly interested in the Sentry and admin
      # e-mail alerts.
      #
      expect(page).to have_text("Thanks, your encounter booking is confirmed")
      expect(page).to have_current_path(encordshelp_magic_link(@encounter_order))

      to_admin = spechelp_decode_multipart()

      expect(to_admin.email.from   ).to eql(["orders@example.com"])
      expect(to_admin.email.to     ).to eql(["orders@example.com"])
      expect(to_admin.email.subject).to eql("[Site Under Test] PROBLEMATIC ENCOUNTER ORDER ALERT")

      expect(to_admin.text).to include(@encounter_order.name)
      expect(to_admin.text).to include(@encounter_order.email)
      expect(to_admin.text).to include(@encounter_order.phone_number)
      expect(to_admin.text).to include("Please reconcile payment records")

      expect(to_admin.html).to include("Please reconcile payment records")
      expect(to_admin.html).to have_css("dd", text: @encounter_order.name)
      expect(to_admin.html).to have_css("dd", text: @encounter_order.number_of_seats)
      spechelp_check_mailto(
        html:    to_admin.html,
        email:   @encounter_order.email,
        subject: "Your booking for \"#{@encounter.title}\"" # (sic.) - best the system can do; local state is not "paid"
      )
      spechelp_check_tel(
        html:  to_admin.html,
        phone: @encounter_order.phone_number
      )
      expect(to_admin.html).to have_link(
        "Manage booking",
        href: admin_encounter_encounter_order_url(encounter_id: @encounter.slug, id: @encounter_order.id)
      )
      expect(to_admin.html).to have_link(
        "here", # ...as in, "You can find a list of all encounter orders <here>"
        href: admin_encounter_encounter_orders_url(encounter_id: @encounter.slug)
      )
    end

    it "of on-success Stripe transaction ('payment intent') ID retrieval" do
      mock_prodid  = "product_test_1234"
      mock_priceid = "price_test_1234"
      mock_csid    = "cs_test_1234"
      mock_payint  = "pi_test_1234"

      expect(Stripe::Product).to receive(:create).once do | args |
        double(id: mock_prodid)
      end

      expect(Stripe::Price).to receive(:create).once do | args |
        double(id: mock_priceid)
      end

      expect(Stripe::Checkout::Session).to receive(:create).once do | args |
        double(url: args[:success_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
      end

      expect(Stripe::Checkout::Session).to receive(:retrieve).with(mock_csid) { raise "An error" }
      expect(Sentry).to receive(:capture_exception).with(kind_of(RuntimeError), extra: { encounter_order_id: @encounter_order.id })

      click_on("Pay now")

      # The Sentry call is expected - see above - and no StripePayment is
      # then recorded, but everything else should still work.
      #
      expect(page).to have_text("Thanks, your encounter booking is confirmed")
      expect(page).to have_current_path(encordshelp_magic_link(@encounter_order))
      expect(StripePrice.count).to eql(1)
      expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
      expect(StripePayment.count).to eql(0)
      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("paid")

      messages    = spechelp_decode_multipart(count: 2)
      to_customer = spechelper_find_in_decoded(messages, to: @encounter_order.email)
      to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

      expect(to_customer).to be_present
      expect(to_admin   ).to be_present
    end

    it "of Stripe product creation" do
      expect(Stripe::Product).to receive(:create) { raise Stripe::StripeError.new("Failed") }
      expect(Sentry).to receive(:capture_exception).with(kind_of(Stripe::StripeError), extra: { encounter_order_id: @encounter_order.id })

      click_on("Pay now")

      expect(StripePrice.count).to eql(0)
      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("new")
      expect(page).to have_text("Sorry, there was a problem trying to talk to the payment provider")
      expect(page).to have_current_path(encordshelp_magic_link(@encounter_order))
    end

    it "of Stripe price creation" do
      expect(Stripe::Product).to receive(:create).once.and_return double(id: "product-1234")
      expect(Stripe::Price).to receive(:create) { raise Stripe::StripeError.new("Failed") }
      expect(Sentry).to receive(:capture_exception).with(kind_of(Stripe::StripeError), extra: { encounter_order_id: @encounter_order.id })

      click_on("Pay now")

      expect(StripePrice.count).to eql(0)
      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("new")
      expect(page).to have_text("Sorry, there was a problem trying to talk to the payment provider")
      expect(page).to have_current_path(encordshelp_magic_link(@encounter_order))
    end

    it "of Stripe checkout session creation" do
      expect(Stripe::Product).to receive(:create).once.and_return double(id: "product-1234")
      expect(Stripe::Price).to receive(:create).once.and_return double(id: "price-1234")
      expect(Stripe::Checkout::Session).to receive(:create) { raise Stripe::StripeError.new("Failed") }
      expect(Sentry).to receive(:capture_exception).with(kind_of(Stripe::StripeError), extra: { encounter_order_id: @encounter_order.id })

      click_on("Pay now")

      expect(StripePrice.count).to eql(1) # Price *did* get created
      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("new")
      expect(page).to have_text("Sorry, there was a problem trying to talk to the payment provider")
      expect(page).to have_current_path(encordshelp_magic_link(@encounter_order))
    end

    it "with other exceptions" do
      expect(Stripe::Product).to receive(:create) { raise "An error" }
      expect(Sentry).to receive(:capture_exception).with(kind_of(RuntimeError), extra: { encounter_order_id: @encounter_order.id })

      click_on("Pay now")

      expect(StripePrice.count).to eql(0)
      expect(EncounterOrder.count).to eql(1)
      expect(@encounter_order.reload.state).to eql("new")
      expect(page).to have_text("Sorry, there was an unexpected problem trying to process the booking")
      expect(page).to have_current_path(encordshelp_magic_link(@encounter_order))
    end
  end # 'context "handling failures"'
end
