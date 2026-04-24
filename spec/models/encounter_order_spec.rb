require "spec_helper.rb"

RSpec.describe EncounterOrder, type: :model do
  include Rails.application.routes.url_helpers
  include EncounterOrdersHelper

  before :each do
    allow(Hcms.config).to receive(:orders_email     ).and_return("orders@example.com")
    allow(Hcms.config).to receive(:contact_tel_human).and_return("022 123 456")
    allow(Hcms.config).to receive(:site_name        ).and_return("Site Under Test")

    default_url_options[:host] = 'www.example.com'
    mock_prodid                = "product_test_1234"
    mock_priceid               = "price_test_1234"

    @encounter = create(:encounter)

    StripePrice.create!(priceable: @encounter, stripe_price_id: mock_priceid)

    allow(Stripe::Price).to receive(:retrieve).with(mock_priceid).and_return double(id: mock_priceid, product: mock_prodid)
    allow(Stripe::Product).to receive(:retrieve).with(mock_prodid).and_return double(id: mock_prodid)
  end

  context "scopes and associations" do
    it "default scope orders by state machine, then created-at-date ascending" do

      # Just test some simple "most important" combinations
      #
      t_ref = Time.now.midnight - 1.day - 18.hours
      eo_2  = create(:encounter_order, encounter: @encounter, created_at: t_ref + 1.hour)
      eo_1  = create(:encounter_order, encounter: @encounter, created_at: t_ref)
      eo_3  = create(:encounter_order, encounter: @encounter, created_at: t_ref + 1.day)

      # The created-at order should be 1, 2, 3 but if order 2 is cancelled it
      # gets lifted due to the by-state ordering's prioritisation; "new" state
      # orders come last, "cancelled" come higher.
      #
      eo_2.update_column(:state, EncounterOrder.states[:cancelled])

      expect(EncounterOrder.all.to_a).to eql([eo_2, eo_1, eo_3])

      # If force order 3 into state "payment_failed", it'll come first.
      #
      eo_3.update_column(:state, EncounterOrder.states[:payment_failed])

      expect(EncounterOrder.all.to_a).to eql([eo_3, eo_2, eo_1])
    end

    it "collates confirmed encounter orders" do
      eos = Array.new(5) { create(:encounter_order, encounter: @encounter, number_of_seats: 1) }

      eos[1].update_column(:state, :reserved)
      eos[3].update_column(:state, :paid)

      expect(EncounterOrder.confirmed.to_a).to match_array([eos[1], eos[3]])
    end

    it "collates problematic encounter orders" do
      eos = Array.new(5) { create(:encounter_order, encounter: @encounter, number_of_seats: 1) }

      eos[3].update_column(:state, :payment_failed)
      eos[4].update_column(:state, :payment_failed)

      expect(EncounterOrder.problematic.to_a).to match_array([eos[3], eos[4]])
    end

    it "collates miscellaneous encounter orders" do
      eos = Array.new(5) { create(:encounter_order, encounter: @encounter, number_of_seats: 1) }

      eos[2].update_column(:state, :cancelled)
      eos[3].update_column(:state, :refunded)

      eos[1].update_column(:state, :paid)
      eos[4].update_column(:state, :payment_failed)

      expect(EncounterOrder.miscellaneous.to_a).to match_array([eos[0], eos[2], eos[3]])
    end

    it "considers the inflight window" do
      eos = Array.new(5) { create(:encounter_order, encounter: @encounter, number_of_seats: 1) }

      eos[1].update_column(:state, :paid)
      eos[2].update_column(:updated_at, Time.now - EncounterOrder::INFLIGHT_WINDOW - 1.second)
      eos[4].update_column(:state, :cancelled)

      # Confirmed orders *or* inflight-windowed new EOs, so 'paid' is
      # included but 'cancelled' is not
      #
      expect(EncounterOrder.inflight.to_a).to match_array([eos[0], eos[1], eos[3]])
    end

    it "considers the stale window" do
      eos = Array.new(5) { create(:encounter_order, encounter: @encounter, number_of_seats: 1) }

      eos[0].update_column(:state,      :paid) # Not "new", so can't be stale
      eos[0].update_column(:updated_at, Time.now - EncounterOrder::STALE_WINDOW - 1.hour)

      eos[1].update_column(:updated_at, Time.now - EncounterOrder::STALE_WINDOW - 1.hour)
      eos[2].update_column(:updated_at, Time.now - EncounterOrder::STALE_WINDOW - 1.second)
      eos[3].update_column(:updated_at, Time.now - EncounterOrder::STALE_WINDOW + 1.second)

      expect(EncounterOrder.stale.to_a).to match_array([eos[1], eos[2]])
    end
  end # 'context "scopes and associations" do'

  context "validations" do
    context "presence" do
      it "checks for basic fields" do
        order = EncounterOrder.new

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
          order = build(:encounter_order, address: nil)

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

          order = build(:encounter_order, address: nil)

          expect(order.valid?).to eql(false)
          expect(order.errors).to have_key(:address)

          order = build(:encounter_order, address: nil, amount_owed: 0)

          expect(order.valid?).to eql(false)
          expect(order.errors).to have_key(:address)
        end

        it "does not require an address if there is no configured threshold" do
          allow(Hcms.config).to receive(:tax_threshold).and_return(nil)

          order = build(:encounter_order, address: nil)

          expect(order.valid?).to eql(true)

          order = build(:encounter_order, address: nil, amount_owed: 0)

          expect(order.valid?).to eql(true)
        end
      end # 'context "addresses" do'
    end # 'context "presence" do'

    context "formats" do

      # Back-end formats human currency strings into smallest currency units as
      # an integer, but in case that has bugs, a must-be-integer validation is
      # included for the amount.
      #
      it "requires an integer numeric number of seats and (defensively) amount owed" do
        order                 = EncounterOrder.new
        order.number_of_seats = "hello"
        order.amount_owed     = "hello"
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to include("must be a positive whole number")
        expect(order.errors.messages_for(:amount_owed    )).to include("is not a number")

        order.number_of_seats = 2.5
        order.amount_owed     = 3.5
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to include("must be a positive whole number")
        expect(order.errors.messages_for(:amount_owed    )).to include("must be an integer")

        order.number_of_seats = 2
        order.amount_owed     = 3
        order.validate()

        expect(order.errors.messages_for(:number_of_seats)).to_not include("must be a positive whole number")
        expect(order.errors.messages_for(:amount_owed    )).to_not include("is not a number")
      end

      it "needs a valid e-mail address" do
        order       = EncounterOrder.new
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
          order = EncounterOrder.new(phone_number: "+44 7855 800")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to include("seems to be invalid - if it is an international number, please include the country code")

          order = EncounterOrder.new(phone_number: "+44 7855 800 700")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
        end

        it "supports local format in the configured country" do
          order = EncounterOrder.new(phone_number: "07855 800")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to include("seems to be invalid - if it is an international number, please include the country code")

          order = EncounterOrder.new(phone_number: "07855 800 700")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
        end

        it "canonicalises international format" do
          order = EncounterOrder.new(phone_number: "+64 022 300 4000") # (note '022')
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
          expect(order.phone_number).to eql("+64 22 300 4000") # (note '22')
        end

        it "canonicalises to local format if matching configured country" do
          order = EncounterOrder.new(phone_number: "+44 7855 800 700")
          order.validate()

          expect(order.errors.messages_for(:phone_number)).to be_empty
          expect(order.phone_number).to eql("07855 800700")
        end
      end # 'context "phone number" do'
    end # 'context "formats" do'
  end # 'context "validations" do'

  context "initialised state" do
    it "sets #frozen_price_on_application only if Encounter#price_on_application? is 'true'" do
      allow(@encounter).to receive(:price_on_application?).and_return(false)

      eo = EncounterOrder.new(encounter: @encounter)

      expect(eo.frozen_price_on_application).to eql(false)

      allow(@encounter).to receive(:price_on_application?).and_return(true)

      eo = EncounterOrder.new(encounter: @encounter)

      expect(eo.frozen_price_on_application).to eql(true)
    end
  end # 'context "initialised state" do'

  context "utilities" do
    context '#human_state' do
      it "works for basic state" do
        expect(create(:encounter_order).human_state()).to eql("In progress")
      end

      it "handles stale encounter orders" do
        eo            = create(:encounter_order)
        eo.updated_at = Time.now - (EncounterOrder::INFLIGHT_WINDOW + 5.seconds)

        expect(eo.human_state()).to eql("Dormant")

        # The above only should apply to 'new' states.
        #
        eo.state = "paid"

        expect(eo.human_state()).to eql("Paid")
      end

      it "handles apparently abandoned encounter orders" do
        eo            = create(:encounter_order)
        eo.updated_at = Time.now - (EncounterOrder::STALE_WINDOW + 5.seconds)

        expect(eo.human_state()).to eql("Abandoned")

        # The above only should apply to 'new' states.
        #
        eo.state = "paid"

        expect(eo.human_state()).to eql("Paid")
      end
    end # 'context '#human_state' do

    it '#human_invoice_number' do
      eo = create(:encounter_order)

      expect(eo.human_invoice_number).to include(eo.invoice_number.to_s)
      expect(eo.human_invoice_number).to include(EncounterOrder::INVOICE_NUMBER_PREFIX)
    end

    it '#token_expires_at' do
      eo = build(:encounter_order)

      expect(eo.token_expires_at).to be_a(Time)
    end

    it '#customer_self_service_possible? delegates to #customer_can_pay_for_booking?' do
      eo = build(:encounter_order)

      expect(eo).to receive(:customer_can_pay_for_booking?).and_return(true)
      expect(eo.customer_self_service_possible?).to eql(true)

      eo = build(:encounter_order)

      expect(eo).to receive(:customer_can_pay_for_booking?).and_return(false)
      expect(eo.customer_self_service_possible?).to eql(false)
    end

    # * EO is new or in a payment-failed state (latter to allow for retries)
    #
    it '#customer_can_pay_for_booking?' do
      eo = build(:encounter_order)

      expect(eo.customer_can_pay_for_booking?).to eql(true)

      eo = build(:encounter_order)
      eo.state = "cancelled"

      expect(eo.customer_can_pay_for_booking?).to eql(false)

      eo = build(:encounter_order)
      eo.state = "payment_failed"

      expect(eo.customer_can_pay_for_booking?).to eql(true)

      eo = build(:encounter_order)
      eo.state = "paid"
    end

    it '#includes_discount?' do
      eo = build(:encounter_order)

      expect(eo.includes_discount?).to eql(false)

      eo.amount_owed -= 1

      expect(eo.includes_discount?).to eql(true)

      # Setting POA should always lead to "no discount" since the whole thing is
      # being charged at a custom price agreed with the customer anyway.
      #
      eo.frozen_price_on_application = true

      expect(eo.includes_discount?).to eql(false)
    end

    # Currently this just reflects the underlying boolean with a different name,
    # but that might change one day.
    #
    it "#price_agreed_by_application?" do
      eo = build(:encounter_order, frozen_price_on_application: false)

      expect(eo.price_agreed_by_application?).to eql(false)

      eo = build(:encounter_order, frozen_price_on_application: true)

      expect(eo.price_agreed_by_application?).to eql(true)
    end

    # Prove that right now, this just consults #price_agreed_by_application?
    #
    it "#all_prices_exclude_sales_tax?" do
      eo = build(:encounter_order, frozen_price_on_application: false)

      expect(eo).to receive(:price_agreed_by_application?).and_return("Mock")
      expect(eo.all_prices_exclude_sales_tax?).to eql("Mock")
    end

    context "#theoretical_amount_owed_without_discounts" do
      it "returns 0 for price-on-application orders" do
        eo = build(:encounter_order)
        eo.frozen_price_on_application = true

        expect(eo.theoretical_amount_owed_without_discounts).to eql(0)
      end

      it "calculates seats * price_per_seat without physical" do
        eo = build(:encounter_order, has_physical: false)

        expect(eo.theoretical_amount_owed_without_discounts).to eql(
          eo.frozen_price_per_seat * eo.number_of_seats
        )
      end

      it "adds frozen_price_physical when has_physical is true" do
        eo = build(:encounter_order, has_physical: true)

        expect(eo.theoretical_amount_owed_without_discounts).to eql(
          eo.frozen_price_per_seat * eo.number_of_seats + eo.frozen_price_physical
        )
      end
    end # 'context "#theoretical_amount_owed_without_discounts" do'

    context "tax calculations" do
      TaxItem   = Data.define(:excl, :incl, :tax)
      TAX_TESTS = [
        TaxItem.new(excl: 1000, incl: 1150, tax: 150), # 1000 * 1.15 = 1150
        TaxItem.new(excl: 1001, incl: 1151, tax: 150), # 1001 * 1.15 = 1151.15 (round down)
        TaxItem.new(excl: 1010, incl: 1162, tax: 152), # 1010 * 1.15 = 1161.50 (round half-up)
        TaxItem.new(excl: 1005, incl: 1156, tax: 151), # 1005 * 1.15 = 1155.75 (round up)
      ]

      context "#amount_owed_plus_tax" do
        before :each do
          allow(Hcms.config).to receive(:tax_rate).and_return("15")
        end

        context "when prices exclude tax (POA)" do
          before :each do
            @eo = build(:encounter_order)
            @eo.frozen_price_on_application = true

            expect(@eo.all_prices_exclude_sales_tax?).to eql(true) # (self-check)
          end

          TAX_TESTS.each do | test |
            it "adds tax (#{test.excl})" do
              @eo.amount_owed = test.excl
              expect(@eo.amount_owed_plus_tax).to eql(test.incl)
            end
          end
        end

        context "when prices include tax" do
          it "returns amount_owed unchanged" do
            eo = build(:encounter_order)
            eo.frozen_price_on_application = false
            original = eo.amount_owed

            expect(eo.all_prices_exclude_sales_tax?).to eql(false) # (self-check)
            expect(eo.amount_owed_plus_tax).to eql(original)
          end
        end
      end # 'context "#amount_owed_plus_tax" do'

      context "#amount_of_tax_owed" do
        context "when prices exclude tax (POA)" do
          before :each do
            allow(Hcms.config).to receive(:tax_rate).and_return("15")

            @eo = build(:encounter_order)
            @eo.frozen_price_on_application = true

            expect(@eo.all_prices_exclude_sales_tax?).to eql(true) # (self-check)
          end

          TAX_TESTS.each do | test |
            it "returns the tax component to be added (#{test.excl})" do
              @eo.amount_owed = test.excl
              expect(@eo.amount_of_tax_owed).to eql(test.tax)
            end
          end
        end # 'context "when prices exclude tax (POA)" do'

        context "when prices include tax, tax_rate configured" do
          before :each do
            allow(Hcms.config).to receive(:tax_rate).and_return("15")

            @eo = build(:encounter_order)
            @eo.frozen_price_on_application = false

            expect(@eo.all_prices_exclude_sales_tax?).to eql(false) # (self-check)
          end

          TAX_TESTS.each do | test |
            it "returns the tax component to be added (#{test.incl})" do
              @eo.amount_owed = test.incl
              expect(@eo.amount_of_tax_owed).to eql(test.tax)
            end
          end
        end # 'context "when prices include tax, tax_rate configured" do'

        context "when no tax_rate configured" do
          before :each do
            allow(Hcms.config).to receive(:tax_rate).and_return(nil)
          end

          it "returns 0" do
            eo = build(:encounter_order)
            expect(eo.amount_of_tax_owed).to eql(0)
          end
        end # 'context "when no tax_rate configured" do'
      end # 'context "#amount_of_tax_owed" do'
    end # 'context "tax calculations" do'
  end # 'context "utilities" do'

  context "state machine" do
    context "miscellaneous" do
      it "returns valid events" do
        eo                   = build(:encounter_order)
        pay_event            = EncounterOrder.aasm(:state).events.find { |e| e.name == :pay }
        payment_failed_event = EncounterOrder.aasm(:state).events.find { |e| e.name == :payment_failed }
        cancel_event         = EncounterOrder.aasm(:state).events.find { |e| e.name == :cancel }
        refund_event         = EncounterOrder.aasm(:state).events.find { |e| e.name == :refund }

        expect(eo.state).to eql(EncounterOrder.states[:new]) # (self-check)
        expect(eo.valid_events()).to match_array([pay_event, payment_failed_event, cancel_event])

        eo.state = "paid"

        expect(eo.valid_events()).to match_array([refund_event])

        eo.amount_owed = 0

        expect(eo.valid_events()).to match_array([])
      end
    end # 'context "miscellaneous" do'

    context "guards" do

      # * Order has an associated encounter
      #
      it '#paid_state_makes_sense?' do
        eo = build(:encounter_order)

        expect(eo.paid_state_makes_sense?).to eql(true)

        eo.encounter = nil

        expect(eo.paid_state_makes_sense?).to eql(false)
      end

      # * Order amount present and greater than zero
      #
      it '#paid_state_makes_sense?' do
        eo = build(:encounter_order)
        eo.amount_owed = nil

        expect(eo.refund_state_makes_sense?).to eql(false)

        eo.amount_owed = 0

        expect(eo.refund_state_makes_sense?).to eql(false)

        eo.amount_owed = 1

        expect(eo.refund_state_makes_sense?).to eql(true)
      end
    end # 'context "guards" do'

    context "transitions" do
      before :each do
        @pay_event            = EncounterOrder.aasm(:state).events.find { |e| e.name == :pay }
        @payment_failed_event = EncounterOrder.aasm(:state).events.find { |e| e.name == :payment_failed }
        @cancel_event         = EncounterOrder.aasm(:state).events.find { |e| e.name == :cancel }
        @refund_event         = EncounterOrder.aasm(:state).events.find { |e| e.name == :refund }

        @eo = create(:encounter_order, encounter: @encounter)

        expect(@eo.state).to eql(EncounterOrder.states[:new]) # (self-check)
      end

      context "from a new (initial) state" do
        context "to paid" do
          it "updates and notifies" do
            @eo.pay_state!

            expect(@eo.valid_events()).to match_array([@refund_event])

            messages    = spechelp_decode_multipart(count: 2)
            to_customer = spechelper_find_in_decoded(messages, to: @eo.email)
            to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")
            total       = spechelp_format_money(@eo.amount_owed, @encounter.currency)

            expect(to_customer).to be_present
            expect(to_customer.email.subject).to include("Booking confirmed")

            expect(to_customer.text).to include(@eo.encounter.title.upcase)
            expect(to_customer.text).to include("Thank you for your payment")
            expect(to_customer.text).to include(total)

            expect(to_customer.html).to include(@eo.encounter.title)
            expect(to_customer.html).to include("Thank you for your payment")
            expect(to_customer.html).to include(total)

            expect(to_admin).to be_present
            expect(to_admin.email.subject).to eql("[Site Under Test] New encounter booking from #{@eo.name}")

            expect(to_admin.text).to include(@eo.encounter.title)
            expect(to_admin.text).to include("A paid encounter booking has been received.")

            expect(to_admin.html).to include(@eo.encounter.title)
            expect(to_admin.html).to include("A paid encounter booking has been received.")
          end
        end # 'context "to paid" do'

        context "to cancelled" do
          it "updates and notifies" do
            @eo.cancel_state!

            expect(@eo.valid_events()).to be_empty

            to_customer = spechelp_decode_multipart()

            expect(to_customer).to be_present
            expect(to_customer.email.to).to eql([@eo.email])
            expect(to_customer.email.subject).to include("Confirmation of cancellation")

            expect(to_customer.text).to include(@eo.encounter.title.upcase)
            expect(to_customer.text).to include("Your booking has been cancelled")

            expect(to_customer.html).to include(@eo.encounter.title)
            expect(to_customer.html).to include("Your booking has been cancelled")
          end
        end # 'context "to cancelled" do'

        # The "payment failed" state at the time of writing is hypothetical as
        # failures happen 'within Stripe', but the code out to work if it ever
        # *did* get run.
        #
        context "payment failures on 'our side'" do

          # We don't notify the admin since they can't really resolve it; the
          # end user might have some idea of the reason for failure but they're
          # advised in the e-mail to get in contact with the site admin directly
          # as resolution is probably best handled by people, not machines.
          #
          it "notifies the end-user" do
            @eo.payment_failed!

            expect(@eo.valid_events()).to match_array([@pay_event, @cancel_event])

            to_customer = spechelp_decode_multipart()
            total       = spechelp_format_money(@eo.amount_owed, @encounter.currency)

            expect(to_customer.email.subject).to include("Payment failure")
            expect(to_customer.email.subject).to include(@encounter.title)

            expect(to_customer.email.from).to eql(["orders@example.com"])

            expect(to_customer.text).to include(@eo.encounter.title.upcase)
            expect(to_customer.text).to include("Unfortunately, there was a problem with your payment")
            expect(to_customer.text).to include("E-mail us by replying")
            expect(to_customer.text).to include("E-mail us by replying to this message")
            expect(to_customer.text).to include("022 123 456")
            expect(to_customer.text).to include(total)
          end
        end # 'context "payment failures on 'our side'" do'
      end # 'context "from a new (initial) state" do'

      context "from paid state" do
        before :each do
          @eo.pay_state!

          perform_enqueued_jobs()
          ActionMailer::Base.deliveries.clear()
        end

        shared_examples "a refund engine which" do | refund_method |
          it "sends e-mails" do
            @eo.send(refund_method)

            to_customer = spechelp_decode_multipart()
            total       = spechelp_format_money(@eo.amount_owed, @encounter.currency)

            expect(to_customer).to be_present
            expect(to_customer.email.to).to eql([@eo.email])
            expect(to_customer.email.subject).to include("Confirmation of refund")

            expect(to_customer.text).to     include(@encounter.title.upcase)
            expect(to_customer.text).to     include("#{total} has been refunded.")
            expect(to_customer.text).to_not include("Unfortunately, this encounter has been cancelled.") # (sic.)

            expect(to_customer.html).to     include(@encounter.title)
            expect(to_customer.html).to     include("#{total}\n  has been refunded.")
            expect(to_customer.html).to_not include("Unfortunately, this encounter has been cancelled.") # (sic.)
          end

          it "refunds in Stripe" do
            mock_payment_intent = "pi_1234"

            StripePayment.create!(
              payable:               @eo,
              stripe_payment_intent: mock_payment_intent
            )

            expect(Stripe::Refund).to receive(:create).with(payment_intent: mock_payment_intent).and_return(double(status: "succeeded"))

            @eo.send(refund_method)

            perform_enqueued_jobs()
            expect(ActionMailer::Base.deliveries.size).to eql(1)

            expect(@eo.reload.stripe_payment).to be_nil
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
              payable:               @eo,
              stripe_payment_intent: mock_payment_intent
            )

            expect(Stripe::Refund).to receive(:create).with(payment_intent: mock_payment_intent).and_return(double(id: mock_refund_id, status: mock_refund_status))

            expect {
              @eo.send(refund_method)
            }.to raise_error(EncounterOrder::RefundError, "Stripe refund error - state \"#{mock_refund_status}\" for ID \"#{mock_refund_id}\"")

            perform_enqueued_jobs()
            expect(ActionMailer::Base.deliveries.size).to eql(0)

            expect(@eo.reload.stripe_payment).to be_present
          end
        end # 'shared_examples "a refund engine which" do'

        context "for normal refunds" do
          it_behaves_like "a refund engine which", :refund_state!
        end # 'context "for normal refunds" do'
      end # 'context "from paid state" do'
    end # 'context "transitions" do'
  end # 'context "state machine" do
end
