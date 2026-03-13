require "spec_helper.rb"

RSpec.describe Order, type: :model do
  include Rails.application.routes.url_helpers
  include OrdersHelper

  before :each do
    allow(Hcms.config).to receive(:orders_email     ).and_return("orders@example.com")
    allow(Hcms.config).to receive(:contact_tel_human).and_return("022 123 456")
    allow(Hcms.config).to receive(:site_name        ).and_return("Site Under Test")

    default_url_options[:host] = 'www.example.com'
    mock_prodid                = "product_test_1234"
    mock_priceid               = "price_test_1234"

    @event = create(:event)

    StripePrice.create!(priceable: @event, stripe_price_id: mock_priceid)

    allow(Stripe::Price).to receive(:retrieve).with(mock_priceid).and_return double(id: mock_priceid, product: mock_prodid)
    allow(Stripe::Product).to receive(:retrieve).with(mock_prodid).and_return double(id: mock_prodid)
  end

  context "scopes and associations" do
    it "default scope orders by state machine, then created-at-date ascending" do

      # Just test some simple "most important" combinations
      #
      t_ref   = Time.now.midnight - 1.day - 18.hours
      order_1 = create(:order, event: @event, created_at: t_ref)
      order_2 = create(:order, event: @event, created_at: t_ref + 1.hour)
      order_3 = create(:order, event: @event, created_at: t_ref + 1.day)

      # The created-at order should be 1, 2, 3 but if order 2 is cancelled it
      # gets lifted due to the by-state ordering's prioritisation; "new" state
      # orders come last, "cancelled" come higher.
      #
      order_2.update_column(:state, Order.states[:cancelled])

      expect(Order.all.to_a).to eql([order_2, order_1, order_3])

      # If force order 3 into state "payment_failed", it'll come first.
      #
      order_3.update_column(:state, Order.states[:payment_failed])

      expect(Order.all.to_a).to eql([order_3, order_2, order_1])
    end

    it "collates confirmed orders" do
      orders = Array.new(5) { create(:order, event: @event, number_of_seats: 1) }

      orders[1].update_column(:state, :reserved)
      orders[3].update_column(:state, :paid)

      expect(Order.confirmed.to_a).to match_array([orders[1], orders[3]])
    end

    it "collates problematic orders" do
      orders = Array.new(5) { create(:order, event: @event, number_of_seats: 1) }

      orders[3].update_column(:state, :payment_failed)
      orders[4].update_column(:state, :payment_failed)

      expect(Order.problematic.to_a).to match_array([orders[3], orders[4]])
    end

    it "collates miscellaneous orders" do
      orders = Array.new(5) { create(:order, event: @event, number_of_seats: 1) }

      orders[2].update_column(:state, :cancelled)
      orders[3].update_column(:state, :refunded)

      orders[1].update_column(:state, :paid)
      orders[4].update_column(:state, :payment_failed)

      expect(Order.miscellaneous.to_a).to match_array([orders[0], orders[2], orders[3]])
    end

    it "considers the inflight window" do
      orders = Array.new(5) { create(:order, event: @event, number_of_seats: 1) }

      orders[1].update_column(:state, :paid)
      orders[2].update_column(:updated_at, Time.now - Order::INFLIGHT_WINDOW - 1.second)
      orders[4].update_column(:state, :cancelled)

      # Confirmed orders *or* inflight-windowed new orders, so 'paid' is
      # included but 'cancelled' is not
      #
      expect(Order.inflight.to_a).to match_array([orders[0], orders[1], orders[3]])
    end

    it "considers the stale window" do
      orders = Array.new(5) { create(:order, event: @event, number_of_seats: 1) }

      orders[0].update_column(:state,      :paid) # Not "new", so can't be stale
      orders[0].update_column(:updated_at, Time.now - Order::STALE_WINDOW - 1.hour)

      orders[1].update_column(:updated_at, Time.now - Order::STALE_WINDOW - 1.hour)
      orders[2].update_column(:updated_at, Time.now - Order::STALE_WINDOW - 1.second)
      orders[3].update_column(:updated_at, Time.now - Order::STALE_WINDOW + 1.second)

      expect(Order.stale.to_a).to match_array([orders[1], orders[2]])
    end
  end # 'context "scopes and associations" do'

  context "validations" do
    context "presence" do
      it "checks for basic fields" do
        order = Order.new

        expect(order).to_not be_valid

        [:name, :email, :number_of_seats, :amount_owed].each do |attr|
          expect(order.errors.messages_for(attr)).to include("must be provided")
        end

        order.name            = "Fred"
        order.email           = "fred@test.com"
        order.number_of_seats = 1
        order.amount_owed     = 1000
        order.validate()

        [:name, :email, :number_of_seats, :amount_owed].each do |attr|
          expect(order.errors.messages_for(attr)).to_not include("must be provided")
        end
      end

      context "addresses" do
        it "requires an address where the total exceeds a configured threshold" do
          order = build(:order, address: nil)

          allow(Hcms.config).to receive(:tax_threshold).and_return(order.amount_owed - 1)

          expect(order.valid?).to eql(false)
          expect(order.errors).to have_key(:address)

          allow(Hcms.config).to receive(:tax_threshold).and_return(order.amount_owed + 1)

          expect(order.valid?).to eql(true)

          allow(Hcms.config).to receive(:tax_threshold).and_return(order.amount_owed)

          expect(order.valid?).to eql(false)
          expect(order.errors).to have_key(:address)
        end

        it "requires an address always if there's a configured zero threshold" do
          allow(Hcms.config).to receive(:tax_threshold).and_return(0)

          order = build(:order, address: nil)

          expect(order.valid?).to eql(false)
          expect(order.errors).to have_key(:address)

          order = build(:order, address: nil, amount_owed: 0)

          expect(order.valid?).to eql(false)
          expect(order.errors).to have_key(:address)
        end

        it "does not require an address if there is no configured threshold" do
          allow(Hcms.config).to receive(:tax_threshold).and_return(nil)

          order = build(:order, address: nil)

          expect(order.valid?).to eql(true)

          order = build(:order, address: nil, amount_owed: 0)

          expect(order.valid?).to eql(true)
        end
      end # 'context "addresses" do'
    end # 'context "presence" do'

    context "formats" do
      it "requires an integer numeric number of seats and amount owed" do
        order                 = Order.new
        order.number_of_seats = "hello"
        order.amount_owed     = "hello"
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to include("must be a whole number")
        expect(order.errors.messages_for(:amount_owed    )).to include("must be a whole number")

        order.number_of_seats = 2.5
        order.amount_owed     = 3.5
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to include("must be a whole number")
        expect(order.errors.messages_for(:amount_owed    )).to include("must be a whole number")

        order.number_of_seats = 2
        order.amount_owed     = 3
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to_not include("must be a whole number")
        expect(order.errors.messages_for(:amount_owed    )).to_not include("must be a whole number")
      end

      it "needs a valid e-mail address" do
        order       = Order.new
        order.email = "invalid"
        order.validate()

        expect(order.errors.messages_for(:email)).to include("must be a valid e-mail address")

        order.email = "valid@test.com"
        order.validate()

        expect(order.errors.messages_for(:email)).to_not include("must be a valid e-mail address")
      end

      context "phone number" do
        around :each do | example |
          old_country_code = Phonelib.default_country
          Phonelib.default_country = "GB"
          example.run()
        ensure
          Phonelib.default_country = old_country_code
        end

        before :each do
          allow(Hcms.config).to receive(:country_code).and_return("GB")
        end

        it "supports international format" do
          order = Order.new(phone_number: "+44 7855 800")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to include("seems to be invalid - if it is an international number, please include the country code")

          order = Order.new(phone_number: "+44 7855 800 700")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
        end

        it "supports local format in the configured country" do
          order = Order.new(phone_number: "07855 800")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to include("seems to be invalid - if it is an international number, please include the country code")

          order = Order.new(phone_number: "07855 800 700")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
        end

        it "canonicalises international format" do
          order = Order.new(phone_number: "+64 022 300 4000") # (note '022')
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
          expect(order.phone_number).to eql("+64 22 300 4000") # (note '22')
        end

        it "canonicalises to local format if matching configured country" do
          order = Order.new(phone_number: "+44 7855 800 700")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
          expect(order.phone_number).to eql("07855 800700")
        end
      end # 'context "phone number" do'
    end # 'context "formats" do'

    context "number of seats" do
      it "supports unlimited seating events" do
        event = create(:event, :uncounted)
        order = build(:order, event: event)

        order.number_of_seats = 10_000
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to be_empty
      end

      it "enforces seat limits by itself" do
        event = create(:event, number_of_seats: 10)
        order = build(:order, event: event)

        order.number_of_seats = 10
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to be_empty

        order.number_of_seats = 11
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to include "requested is too high - only 10 left"
      end

      it "accounts for in-flight orders" do
        event          = create(:event, number_of_seats: 12)
        order_new      = create(:order, event: event, number_of_seats: 1)
        order_reserved = create(:order, event: event, number_of_seats: 2)
        order_paid     = create(:order, event: event, number_of_seats: 3)
        order          =  build(:order, event: event, number_of_seats: 5)

        order_reserved.reserve_state!
        event.start_public_purchases_state!
        order_paid.pay_state!

        # (Self-checks)
        #
        expect(order_new     .state).to eql("new")
        expect(order_reserved.state).to eql("reserved")
        expect(order_paid    .state).to eql("paid")
        expect(order).to be_valid

        order.number_of_seats = 6

        expect(order).to be_valid

        order.number_of_seats = 7

        expect(order).to_not be_valid
        expect(order.errors.messages_for(:number_of_seats)).to include "requested is too high - only 6 left"

        order_reserved.cancel_state!

        expect(order).to be_valid
      end
    end # 'context "number of seats"'
  end # 'context "validations" do'

  context "utilities" do
    context '#human_state' do
      it "works for basic state" do
        expect(build(:order).human_state()).to eql("In progress")
      end

      it "handles stale orders" do
        order            = create(:order)
        order.updated_at = Time.now - (Order::INFLIGHT_WINDOW + 5.seconds)

        expect(order.human_state()).to eql("Dormant")

        # The above only should apply to 'new' states.
        #
        order.state = "reserved"

        expect(order.human_state()).to eql("Reserved")
      end

      it "handles apparently abandoned orders" do
        order            = create(:order)
        order.updated_at = Time.now - (Order::STALE_WINDOW + 5.seconds)

        expect(order.human_state()).to eql("Abandoned")

        # The above only should apply to 'new' states.
        #
        order.state = "reserved"

        expect(order.human_state()).to eql("Reserved")
      end
    end # 'context '#human_state' do

    it '#human_invoice_number' do
      order = create(:order)

      expect(order.human_invoice_number).to include(order.invoice_number.to_s)
      expect(order.human_invoice_number).to include(Order::INVOICE_NUMBER_PREFIX)
    end

    it '#token_expires_at' do
      order = build(:order)

      expect(order.token_expires_at).to be_a(Time)
    end

    it '#customer_self_service_possible?' do
      order = build(:order)

      # We expect this to lean on other related methods but use "allow" rather
      # than "expect" since short circuit evaluation may stop one of the checks
      # from being needed (but don't assume that call order here).
      #
      allow(order).to receive(:customer_can_pay_for_reservation?).and_return(true)
      allow(order).to receive(:customer_can_pay_for_booking?    ).and_return(true)

      expect(order.customer_self_service_possible?).to eql(true)

      order = build(:order)

      allow(order).to receive(:customer_can_pay_for_reservation?).and_return(true)
      allow(order).to receive(:customer_can_pay_for_booking?    ).and_return(false)

      expect(order.customer_self_service_possible?).to eql(true)

      order = build(:order)

      allow(order).to receive(:customer_can_pay_for_reservation?).and_return(false)
      allow(order).to receive(:customer_can_pay_for_booking?    ).and_return(true)

      expect(order.customer_self_service_possible?).to eql(true)

      order = build(:order)

      allow(order).to receive(:customer_can_pay_for_reservation?).and_return(false)
      allow(order).to receive(:customer_can_pay_for_booking?    ).and_return(false)

      expect(order.customer_self_service_possible?).to eql(false)
    end

    # * Order in a reserved or payment-failed state (latter to allow for retries)
    # * Event is accepting reserver or public purchases
    # * Event has not yet started
    #
    it '#customer_can_pay_for_reservation?' do
      order = build(:order)

      expect(order.customer_can_pay_for_reservation?).to eql(false)

      order.event.state = "reserver_purchases"
      order.state       = "reserved"

      expect(order.customer_can_pay_for_reservation?).to eql(true)

      order.state = "paid"

      expect(order.customer_can_pay_for_reservation?).to eql(false)

      order.state = "payment_failed"

      expect(order.customer_can_pay_for_reservation?).to eql(true)

      order.event.state = "public_purchases"

      expect(order.customer_can_pay_for_reservation?).to eql(true)

      order.event.state = "presales"

      expect(order.customer_can_pay_for_reservation?).to eql(false)

      order.event.state = "public_purchases"

      expect(order.customer_can_pay_for_reservation?).to eql(true)

      order.event.starts_at = Time.now - 1.minute

      expect(order.customer_can_pay_for_reservation?).to eql(false)
    end

    # Conditions for reservation payment are met, since that's a way to pay for
    # a booking from a position of having previously reserved a spot, or:
    #
    # * Order is new or in a payment-failed state (latter to allow for retries)
    # * Event is accepting public purchases
    # * Event has not yet started
    #
    it '#customer_can_pay_for_booking?' do
      order = build(:order)

      expect(order.customer_can_pay_for_booking?).to eql(false)
      expect(order).to receive(:customer_can_pay_for_reservation?).and_return(true)
      expect(order.customer_can_pay_for_booking?).to eql(true)

      order = build(:order)

      order.event.state = "public_purchases"

      expect(order.customer_can_pay_for_booking?).to eql(true)

      order.state = "cancelled"

      expect(order.customer_can_pay_for_booking?).to eql(false)

      order.state = "payment_failed"

      expect(order.customer_can_pay_for_booking?).to eql(true)

      order.event.starts_at = Time.now - 1.minute

      expect(order.customer_can_pay_for_booking?).to eql(false)
    end

    it '#includes_discount?' do
      order = build(:order)

      expect(order.includes_discount?).to eql(false)

      order.amount_owed -= 1

      expect(order.includes_discount?).to eql(true)
    end
  end # 'context "utilities" do'

  context "state machine" do
    context "miscellaneous" do
      it "returns valid events" do
        order                = build(:order)
        reserve_event        = Order.aasm(:state).events.find { |e| e.name == :reserve }
        pay_event            = Order.aasm(:state).events.find { |e| e.name == :pay }
        payment_failed_event = Order.aasm(:state).events.find { |e| e.name == :payment_failed }
        cancel_event         = Order.aasm(:state).events.find { |e| e.name == :cancel }

        expect(order.state).to eql(Order.states[:new]) # (self-check)
        expect(order.valid_events()).to match_array([reserve_event, payment_failed_event, cancel_event])

        order.event.start_public_purchases_state!

        # Note we swap "reserve" for "pay" now that the event has opened up for
        # purchases.
        #
        expect(order.valid_events()).to match_array([pay_event, payment_failed_event, cancel_event])
      end
    end # 'context "miscellaneous" do'

    context "guards" do

      # * Order has an associated event
      # * Order permits reservation payment or booking payment
      #
      it '#paid_state_makes_sense?' do
        order = build(:order)

        expect(order.paid_state_makes_sense?).to eql(false)

        allow(order).to receive(:customer_can_pay_for_reservation?).and_return(true)

        expect(order.paid_state_makes_sense?).to eql(true)

        order = build(:order)
        allow(order).to receive(:customer_can_pay_for_booking?).and_return(true)

        expect(order.paid_state_makes_sense?).to eql(true)

        order.event = nil

        expect(order.paid_state_makes_sense?).to eql(false)
      end

      # * Order has an associated event
      # * Event is in a presales state
      # * Event has not started
      #
      it '#reservation_makes_sense?' do
        order = build(:order)

        expect(order.reservation_makes_sense?).to eql(true) # (due to default factory setup)

        order.event.state = "reserver_purchases"

        expect(order.reservation_makes_sense?).to eql(false)

        order.event.state = "presales"

        expect(order.reservation_makes_sense?).to eql(true)

        order.event.starts_at = Time.now - 1.minute

        expect(order.reservation_makes_sense?).to eql(false)

        order.event.starts_at = Time.now + 1.hour

        expect(order.reservation_makes_sense?).to eql(true)

        order.event = nil

        expect(order.reservation_makes_sense?).to eql(false)
      end

      # Outside the no-refunds window => refunds *are* permitted if:
      #
      # * Event is cancelled
      # * The refunds window is configured to zero
      # * The event starts within the window
      #
      it '#outside_no_refunds_window?' do
        order                 = build(:order)
        order.event.starts_at = Time.now + 25.hours

        allow(Hcms.config).to receive(:no_refunds_window).and_return(0)

        expect(order.outside_no_refunds_window?).to eql(true)

        allow(Hcms.config).to receive(:no_refunds_window).and_return(10) # (days)

        expect(order.outside_no_refunds_window?).to eql(false)

        allow(Hcms.config).to receive(:no_refunds_window).and_return(1) # (day)

        expect(order.outside_no_refunds_window?).to eql(true)

        # Repeat this just to prove the outside-window return value is restored
        # to 'false', so that the alternating pattern of true-false shows that
        # the test isn't just getting (say) a previously cached answer back.
        #
        allow(Hcms.config).to receive(:no_refunds_window).and_return(10) # (days)
        expect(order.outside_no_refunds_window?).to eql(false)

        order.event.state = "cancelled"

        expect(order.outside_no_refunds_window?).to eql(true)
      end
    end # 'context "guards" do'

    context "transitions" do
      before :each do
        @reserve_event        = Order.aasm(:state).events.find { |e| e.name == :reserve }
        @pay_event            = Order.aasm(:state).events.find { |e| e.name == :pay }
        @payment_failed_event = Order.aasm(:state).events.find { |e| e.name == :payment_failed }
        @cancel_event         = Order.aasm(:state).events.find { |e| e.name == :cancel }
        @refund_event         = Order.aasm(:state).events.find { |e| e.name == :refund }
        @force_refund_event   = Order.aasm(:state).events.find { |e| e.name == :force_refund }

        @order = create(:order, event: @event)

        expect(@order.state).to eql(Order.states[:new]) # (self-check)
      end

      context "from a new (initial) state" do
        context "to reserved" do
          it "updates and notifies" do
            @order.reserve_state!

            expect(@order.valid_events()).to match_array([@payment_failed_event, @cancel_event])

            messages    = spechelp_decode_multipart(count: 2)
            to_customer = spechelper_find_in_decoded(messages, to: @order.email)
            to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

            expect(to_customer).to be_present
            expect(to_customer.email.subject).to include("Reservation confirmed")

            expect(to_customer.text).to include(@order.event.title.upcase)
            expect(to_customer.text).to include("Thank you for your reservation")

            expect(to_customer.html).to include(@order.event.title)
            expect(to_customer.html).to include("Thank you for your reservation")

            expect(to_admin).to be_present
            expect(to_admin.email.subject).to eql("[Site Under Test] New reservation from #{@order.name}")

            expect(to_admin.text).to include(@order.event.title)
            expect(to_admin.text).to include("A new event reservation has been made")

            expect(to_admin.html).to include(@order.event.title)
            expect(to_admin.html).to include("A new event reservation has been made")
          end
        end # 'context "to reserved" do'

        context "to paid" do
          before :each do
            allow(Hcms.config).to receive(:no_refunds_window).and_return(0) # (refunds always allowed)
            @event.start_public_purchases_state!
          end

          it "updates and notifies" do
            @order.pay_state!

            expect(@order.valid_events()).to match_array([@refund_event, @force_refund_event])

            messages    = spechelp_decode_multipart(count: 2)
            to_customer = spechelper_find_in_decoded(messages, to: @order.email)
            to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")
            total       = spechelp_format_money(@order.amount_owed, @event.currency)

            expect(to_customer).to be_present
            expect(to_customer.email.subject).to include("Booking confirmed")

            expect(to_customer.text).to include(@order.event.title.upcase)
            expect(to_customer.text).to include("Thank you for your payment")
            expect(to_customer.text).to include(total)

            expect(to_customer.html).to include(@order.event.title)
            expect(to_customer.html).to include("Thank you for your payment")
            expect(to_customer.html).to include(total)

            expect(to_admin).to be_present
            expect(to_admin.email.subject).to eql("[Site Under Test] New paid booking from #{@order.name}")

            expect(to_admin.text).to include(@order.event.title)
            expect(to_admin.text).to include("A paid booking has been received.")

            expect(to_admin.html).to include(@order.event.title)
            expect(to_admin.html).to include("A paid booking has been received.")
          end
        end # 'context "to paid" do'

        # Arguably, when going from a "new" rather than "reserved" state, no
        # e-mail should be sent. But maybe the user thought 'new' was indeed a
        # reservation of some kind; and in practice, we usually delete a "new"
        # state order that is actively cancelled rather than change state. This
        # is on balance an OK behaviour that provides an alternative to the
        # silence of a deleted order, should it be wanted.
        #
        context "to cancelled" do
          it "updates and notifies" do
            @order.cancel_state!

            expect(@order.valid_events()).to be_empty

            to_customer = spechelp_decode_multipart()

            expect(to_customer).to be_present
            expect(to_customer.email.to).to eql([@order.email])
            expect(to_customer.email.subject).to include("Confirmation of cancellation")

            expect(to_customer.text).to include(@order.event.title.upcase)
            expect(to_customer.text).to include("Your reservation for this event has been cancelled")

            expect(to_customer.html).to include(@order.event.title)
            expect(to_customer.html).to include("Your reservation for this event has been cancelled")
          end
        end # 'context "to cancelled" do'
      end # 'context "from a new (initial) state" do'

      context "from a reserved state" do
        before :each do
          @order.reserve_state!

          perform_enqueued_jobs()
          ActionMailer::Base.deliveries.clear()
        end

        # Note this is *order* cancellation, so user-initiated (or via admin at,
        # we assume, a user's behest). Event cancellation and its impact on
        # orders in various states is covered in 'spec/models/event_spec.rb'.
        #
        context "to cancelled" do
          it "updates and notifies" do
            @order.cancel_state!

            expect(@order.valid_events()).to be_empty

            messages    = spechelp_decode_multipart(count: 2)
            to_customer = spechelper_find_in_decoded(messages, to: @order.email)
            to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

            expect(to_customer).to be_present
            expect(to_customer.email.to).to eql([@order.email])
            expect(to_customer.email.subject).to include("Confirmation of cancellation")

            expect(to_customer.text).to     include(@order.event.title.upcase)
            expect(to_customer.text).to     include("Your reservation for this event has been cancelled")
            expect(to_customer.text).to_not include("Unfortunately, this event has been cancelled.") # (sic.)

            expect(to_customer.html).to     include(@order.event.title)
            expect(to_customer.html).to     include("Your reservation for this event has been cancelled")
            expect(to_customer.html).to_not include("Unfortunately, this event has been cancelled.") # (sic.)
          end
        end # 'context "to cancelled" do'

        context "to paid" do
          before :each do
            @event.start_public_purchases_state!

            perform_enqueued_jobs()
            ActionMailer::Base.deliveries.clear()
          end

          it "updates and notifies" do
            @order.pay_state!

            expect(@order.valid_events()).to match_array([@refund_event, @force_refund_event])

            messages    = spechelp_decode_multipart(count: 2)
            to_customer = spechelper_find_in_decoded(messages, to: @order.email)
            to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")
            total       = spechelp_format_money(@order.amount_owed, @event.currency)

            expect(to_customer).to be_present
            expect(to_customer.email.subject).to include("Booking confirmed")

            expect(to_customer.text).to include(@order.event.title.upcase)
            expect(to_customer.text).to include("Thank you for your payment")
            expect(to_customer.text).to include(total)

            expect(to_customer.html).to include(@order.event.title)
            expect(to_customer.html).to include("Thank you for your payment")
            expect(to_customer.html).to include(total)

            expect(to_admin).to be_present
            expect(to_admin.email.subject).to eql("[Site Under Test] New paid booking from #{@order.name}")

            expect(to_admin.text).to include(@order.event.title)
            expect(to_admin.text).to include("A paid booking has been received.")

            expect(to_admin.html).to include(@order.event.title)
            expect(to_admin.html).to include("A paid booking has been received.")
          end
        end # 'context "to paid" do'

        # The "payment failed" state at the time of writing is hypothetical as
        # failures happen 'within Stripe', but the code out to work if it ever
        # *did* get run.
        #
        context "payment failures on 'our side'" do
          before :each do
            @event.start_public_purchases_state!

            perform_enqueued_jobs()
            ActionMailer::Base.deliveries.clear()
          end

          # We don't notify the admin since they can't really resolve it; the
          # end user might have some idea of the reason for failure but they're
          # advised in the e-mail to get in contact with the site admin directly
          # as resolution is probably best handled by people, not machines.
          #
          it "notifies the end-user" do
            @order.payment_failed!

            expect(@order.valid_events()).to match_array([@pay_event, @cancel_event])

            to_customer = spechelp_decode_multipart()
            total       = spechelp_format_money(@order.amount_owed, @event.currency)

            expect(to_customer.email.subject).to include("Payment failure")
            expect(to_customer.email.subject).to include(@event.title)

            expect(to_customer.email.from).to eql(["orders@example.com"])

            expect(to_customer.text).to include(@order.event.title.upcase)
            expect(to_customer.text).to include("Unfortunately, there was a problem with your payment")
            expect(to_customer.text).to include("E-mail us by replying")
            expect(to_customer.text).to include("E-mail us by replying to this message")
            expect(to_customer.text).to include("022 123 456")
            expect(to_customer.text).to include(total)
          end
        end # 'context "payment failures on 'our side'" do'
      end # 'context "from a reserved state" do'

      context "from paid state" do
        before :each do
          @event.start_public_purchases_state!
          @order.pay_state!

          perform_enqueued_jobs()
          ActionMailer::Base.deliveries.clear()
        end

        shared_examples "a refund engine which" do | refund_method |
          it "sends e-mails" do
            @order.send(refund_method)

            to_customer = spechelp_decode_multipart()
            total       = spechelp_format_money(@order.amount_owed, @event.currency)

            expect(to_customer).to be_present
            expect(to_customer.email.to).to eql([@order.email])
            expect(to_customer.email.subject).to include("Confirmation of refund")

            expect(to_customer.text).to     include(@event.title.upcase)
            expect(to_customer.text).to     include("#{total} has been refunded.")
            expect(to_customer.text).to_not include("Unfortunately, this event has been cancelled.") # (sic.)

            expect(to_customer.html).to     include(@event.title)
            expect(to_customer.html).to     include("#{total}\n  has been refunded.")
            expect(to_customer.html).to_not include("Unfortunately, this event has been cancelled.") # (sic.)
          end

          it "refunds in Stripe" do
            mock_payment_intent = "pi_1234"

            StripePayment.create!(
              payable:               @order,
              stripe_payment_intent: mock_payment_intent
            )

            expect(Stripe::Refund).to receive(:create).with(payment_intent: mock_payment_intent).and_return(double(status: "succeeded"))

            @order.send(refund_method)

            perform_enqueued_jobs()
            expect(ActionMailer::Base.deliveries.size).to eql(1)

            expect(@order.reload.stripe_payment).to be_nil
          end

          # Raises, since that means the user or admin sees a nasty error and is
          # motivated to try and resolve it; Sentry will capture that; we do not
          # change state otherwise, so no misleading e-mail gets sent.
          #
          it "throws Stripe errors intentionally and does not notify the user" do
            mock_payment_intent = "pi_1234"
            mock_refund_id      = "re_1234"
            mock_refund_status  = "failed"

            StripePayment.create!(
              payable:               @order,
              stripe_payment_intent: mock_payment_intent
            )

            expect(Stripe::Refund).to receive(:create).with(payment_intent: mock_payment_intent).and_return(double(id: mock_refund_id, status: mock_refund_status))

            expect {
              @order.send(refund_method)
            }.to raise_error("Stripe refund error - state \"#{mock_refund_status}\" for ID \"#{mock_refund_id}\"")

            perform_enqueued_jobs()
            expect(ActionMailer::Base.deliveries.size).to eql(0)

            expect(@order.reload.stripe_payment).to be_present
          end
        end # 'shared_examples "a refund engine which" do'

        context "for normal refunds" do
          it_behaves_like "a refund engine which", :refund_state!
        end # 'context "for normal refunds" do'

        context "for forced refunds" do
          before :each do
            allow(Hcms.config).to receive(:no_refunds_window).and_return(2) # (days)
            @order.event.starts_at = Time.now - 1.hour
          end

          it_behaves_like "a refund engine which", :force_refund_state!
        end # 'context "for forced refunds" do'
      end # 'context "from paid state" do'
    end # 'context "transitions" do'
  end # 'context "state machine" do
end
