require "spec_helper.rb"

RSpec.describe Order, type: :model do
  include Rails.application.routes.url_helpers
  include OrdersHelper

  before :each do
    allow(Hcms.config).to receive(:orders_email).and_return("orders@example.com")

    default_url_options[:host] = 'www.example.com'
    mock_prodid                = "product_test_1234"
    mock_priceid               = "price_test_1234"

    @event = create(:event)

    StripePrice.create!(priceable: @event, stripe_price_id: mock_priceid)

    allow(Stripe::Price).to receive(:retrieve).with(mock_priceid).and_return double(id: mock_priceid, product: mock_prodid)
    allow(Stripe::Product).to receive(:retrieve).with(mock_prodid).and_return double(id: mock_prodid)
  end

  xcontext "scopes and associations" do
    it "default scope orders by state machine, then starts-at-date ascending" do
      page = create(:page, :events)

      # Just test some simple "most important" combinations
      #
      t_ref   = Time.now.midnight + 1.day + 18.hours
      event_1 = create(:event, page: page, starts_at: t_ref,         ends_at: t_ref + 2.hours)
      event_2 = create(:event, page: page, starts_at: t_ref,         ends_at: t_ref + 2.hours)
      event_3 = create(:event, page: page, starts_at: t_ref + 1.day, ends_at: t_ref + 2.hours + 1.day)

      event_2.update_column(:state, Event.states[:cancelled])

      expect(event_1.page).to eql(page) # (basic sanity check)
      expect(event_2.page).to eql(page)
      expect(event_3.page).to eql(page)

      expect(Event.all.to_a).to eql([event_1, event_3, event_2])
    end

    it "::for_navigation only includes published, non-hidden events" do
      page = create(:page, :events)

      event_1 = create(:event, page: page); event_1.revisions.update_all(published: false)
      event_2 = create(:event, page: page); event_2.revisions.update_all(published: true)
      event_3 = create(:event, page: page); event_3.revisions.update_all(published: true); event_3.update!(hidden: true)

      expect(Event.for_navigation).to match_array([event_2])
    end
  end # 'context "scopes and associations" do'

  context "validations" do
  end # 'context "validations" do'

  context "utilities" do
    xit '#human_state' do
      expect(build(:event).human_state()).to eql("Reservations only (pre-sale)")
    end
  end # 'context "utilities" do'

  context "state machine" do
    context "miscellaneous" do
      xit "returns valid events" do
        event           = build(:event)
        purchases_event = Event.aasm(:state).events.find { |e| e.name == :start_public_purchases }
        cancel_event    = Event.aasm(:state).events.find { |e| e.name == :cancel }

        expect(event.state).to eql(Event.states[:presales]) # (self-check)
        expect(event.valid_events()).to match_array([purchases_event, cancel_event])
      end
    end # 'context "miscellaneous" do'

    context "guards" do
      xit '#has_reservers?' do
        event = create(:event)
        order = create(:order, event: event)

        expect(order.state).to eql(Order.states[:new]) # (self-check)
        expect(event.has_reservers?).to eql(false)

        order.reserve_state!

        expect(event.has_reservers?).to eql(true)

        event.start_reserver_purchases_state!
        order.pay_state!

        expect(event.has_reservers?).to eql(false)
      end
    end # 'context "guards" do'

    context "transitions" do
      before :each do
        # @reservers_event = Event.aasm(:state).events.find { |e| e.name == :start_reserver_purchases }
        # @public_event    = Event.aasm(:state).events.find { |e| e.name == :start_public_purchases }
        # @archive_event   = Event.aasm(:state).events.find { |e| e.name == :archive }
        # @cancel_event    = Event.aasm(:state).events.find { |e| e.name == :cancel }
        #
        # @event = create(:event)
        #
        # expect(@event.state).to eql(Event.states[:presales]) # (self-check)
      end

      context "from a new (initial) state" do
        context "to reserved" do
        end # 'context "to reserved" do'

        context "to paid" do
        end # 'context "to paid" do'

        context "to cancelled" do
        end # 'context "to cancelled" do'
      end # 'context "from a new (initial) state" do'

      context "from a reserved state" do
        context "to cancelled" do
        end # 'context "to cancelled" do'

        context "to paid" do
        end # 'context "to paid" do'
      end # 'context "from a reserved state" do'

      context "from paid state" do
        before :each do
          @event.start_public_purchases_state!

          @order = create(:order, event: @event)
          @order.pay_state!

          perform_enqueued_jobs()
          ActionMailer::Base.deliveries.clear()
        end

        context "to refunded" do
          it "sends e-mails" do
            @order.refund_state!

            to_customer = spechelp_decode_multipart()
            total       = spechelp_format_money(@order.amount_owed, @event.currency)

            expect(to_customer).to be_present
            expect(to_customer.email.subject).to include("Confirmation of refund")

            expect(to_customer.text).to     include(@event.title.upcase)
            expect(to_customer.text).to     include("#{total} has been refunded.")
            expect(to_customer.text).to_not include("Unfortunately, this event has been cancelled.") # (sic.)

            expect(to_customer.html).to     include(@event.title)
            expect(to_customer.html).to include("#{total}\n  has been refunded.")
            expect(to_customer.html).to_not include("Unfortunately, this event has been cancelled.") # (sic.)
          end

          it "refunds in Stripe" do
            mock_payment_intent = "pi_1234"

            StripePayment.create!(
              payable:               @order,
              stripe_payment_intent: mock_payment_intent
            )

            expect(Stripe::Refund).to receive(:create).with(payment_intent: mock_payment_intent).and_return(double(status: "succeeded"))

            @order.refund_state!

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
              @order.refund_state!
            }.to raise_error("Stripe refund error - state \"#{mock_refund_status}\" for ID \"#{mock_refund_id}\"")

            perform_enqueued_jobs()
            expect(ActionMailer::Base.deliveries.size).to eql(0)

            expect(@order.reload.stripe_payment).to be_present
          end
        end # 'context "to refunded" do'
      end # 'context "from paid state" do'
    end # 'context "transitions" do'
  end # 'context "state machine" do
end
