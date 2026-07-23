require "spec_helper.rb"

RSpec.describe Event, type: :model do

  # A little helper to DRY things a tiny bit.
  #
  def expect_stripe_to_be_made_inactive_via(event, simulated_failure: false)
    mock_prodid  = "product_test_1234"
    mock_priceid = "price_test_1234"

    StripePrice.create!(priceable: event, stripe_price_id: mock_priceid)

    expect(Stripe::Price).to receive(:retrieve).with(mock_priceid).and_return double(id: mock_priceid, product: mock_prodid)
    expect(Stripe::Product).to receive(:retrieve).with(mock_prodid).and_return double(id: mock_prodid)

    expect(Stripe::Product).to receive(:update).with(mock_prodid, {active: false})

    if simulated_failure
      expect(Stripe::Price).to receive(:update) { raise "An error" }
    else
      expect(Stripe::Price).to receive(:update).with(mock_priceid, {active: false})
    end
  end

  it "is an Editable" do # (because that's tested separately, so no need to duplicate tests here)
    expect(Event.ancestors).to include(Editable)
  end

  context "scopes and associations" do
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

  context "initialisation" do
    it "sets currency" do
      allow(Hcms.config).to receive(:currency).and_return("XYZ")
      expect(Event.new.currency).to eql("XYZ")
    end

    it "sets a time of 9am to 5pm today if 'now' is 8am or earlier" do
      base_time = Time.zone.local(2026, 1, 1, 8, 00) # 8:00am

      travel_to(base_time) do
        expect(Event.new.starts_at).to eql(base_time + 1.hour)
        expect(Event.new.ends_at  ).to eql(base_time + 9.hours)
      end
    end

    it "sets a time of 9am to 5pm tomorrow if 'now' is after 8am" do
      base_time = Time.zone.local(2026, 1, 1, 8, 01) # 8:01am

      travel_to(base_time) do
        expect(Event.new.starts_at).to eql(base_time + 1.day - 1.minute + 1.hour)
        expect(Event.new.ends_at  ).to eql(base_time + 1.day - 1.minute + 9.hours)
      end
    end
  end # 'context "initialisation" do'

  context "validations" do
    it "requires a title, summary, body and hero image" do
      event = build(:event)

      expect(event).to be_valid # (self-check)

      event.revisions.first.summary = nil

      expect(event).to_not be_valid
      expect(event.errors.of_kind?(:summary, :blank)).to eql(true)

      event.revisions.first.summary = "OK"

      expect(event).to be_valid

      event.revisions.first.body = nil

      expect(event).to_not be_valid
      expect(event.errors.of_kind?(:body, :blank)).to eql(true)

      event.revisions.first.body = "<p>OK</p>"

      expect(event).to be_valid

      event.event_hero_image = nil

      expect(event).to_not be_valid
      expect(event.errors.of_kind?(:event_hero_image, :blank)).to eql(true)
    end

    it "requires a future start time and end time, and start to be before end" do
      event = build(:event)
      event.starts_at = Time.now - 1.day

      expect(event).to_not be_valid
      expect(event.errors.of_kind?(:starts_at, :greater_than)).to eql(true)
      expect(event.errors.of_kind?(:ends_at,   :greater_than)).to eql(false)

      event.ends_at = event.starts_at + 1.day

      expect(event).to_not be_valid
      expect(event.errors.of_kind?(:starts_at, :greater_than)).to eql(true)
      expect(event.errors.of_kind?(:ends_at,   :greater_than)).to eql(true)

      event.starts_at = Time.now + 1.day + 1.hour
      event.ends_at   = Time.now + 1.day

      expect(event).to_not be_valid
      expect(event.errors.of_kind?(:ends_at, "must be after the start time")).to eql(true)
    end

    it "allows an in-the-past start time and end time, if in/entering an 'archived' state" do
      event           = create(:event)
      event.starts_at = Time.now - 18.hours
      event.ends_at   = Time.now - 12.hours
      event.archive_state()

      expect(event).to be_valid
    end

    it "allows an in-the-past start time and end time, if in/entering a 'cancelled' state" do
      event           = create(:event)
      event.starts_at = Time.now - 18.hours
      event.ends_at   = Time.now - 12.hours
      event.cancel_state()

      expect(event).to be_valid
    end
  end # 'context "validations" do'

  it "responds correctly to trait enquiries" do
    event = build(:event)

    expect(event.is_normal_type?    ).to eql(false)
    expect(event.is_form_type?      ).to eql(false)
    expect(event.is_blog_type?      ).to eql(false)
    expect(event.is_events_type?    ).to eql(false)
    expect(event.is_encounters_type?).to eql(false)
    expect(event.is_article?        ).to eql(false)
    expect(event.is_encounter?      ).to eql(false)
    expect(event.is_event?          ).to eql(true)
  end

  context "base class overrides" do
    context "#for_navigation?" do
      it "returns 'true' for a not-hidden page with a published revision that isn't hidden" do
        page = create(:page)

        event_1 = create(:event, page: page); event_1.revisions.update_all(published: false)
        event_2 = create(:event, page: page); event_2.revisions.update_all(published: true)
        event_3 = create(:event, page: page); event_3.revisions.update_all(published: true); event_3.update_column(:hidden, true)

        expect(event_1.for_navigation?).to eql(false)
        expect(event_2.for_navigation?).to eql(true)
        expect(event_3.for_navigation?).to eql(false)
      end
    end # 'context "#for_navigation?" do'
  end # 'context "base class overrides" do'

  context "miscellaneous" do
    it "#free_of_charge?" do
      expect(build(:event       ).free_of_charge?).to eql(false)
      expect(build(:event, :free).free_of_charge?).to eql(true)
    end

    it "#unrestricted_seating?" do
      expect(build(:event            ).unrestricted_seating?).to eql(false)
      expect(build(:event, :uncounted).unrestricted_seating?).to eql(true)
    end

    context "#provisional_seats_remaining / #provisional_seats_remaining?" do
      it 'with unrestricted seating' do
        event = build(:event, :uncounted)

        expect(event.provisional_seats_remaining ).to be_nil
        expect(event.provisional_seats_remaining?).to eql(true)
      end

      it 'with counted seating' do
        event = create(:event, number_of_seats: 10)

        expect(event.provisional_seats_remaining ).to eql(10)
        expect(event.provisional_seats_remaining?).to eql(true)

        order_1 = create(:order, event: event, number_of_seats: 2)
        order_2 = create(:order, event: event, number_of_seats: 3); order_2.update_column(:state, Order.states[:paid])
        order_3 = create(:order, event: event, number_of_seats: 4); order_3.update_column(:state, Order.states[:cancelled])

        # It's memoised for performance...
        #
        expect(event.provisional_seats_remaining).to eql(10)

        # ...so we have to get a new instance
        #
        event = Event.find(event.id)
        expect(event.provisional_seats_remaining ).to eql(5) # 10 minus sum of Reserved order 1 and Paid order 2 seats
        expect(event.provisional_seats_remaining?).to eql(true)
      end

      it 'will not drop below zero for over-subscribed events' do
        event = create(:event, number_of_seats: 20)
        order = create(:order, event: event, number_of_seats: 20)
        event.update!(number_of_seats: 10)

        expect(event.provisional_seats_remaining ).to be_zero
        expect(event.provisional_seats_remaining?).to eql(false)
      end
    end # 'context "#provisional_seats_remaining" do'

    context "#confirmed_seats_remaining" do
      it 'with unrestricted seating' do
        event = build(:event, :uncounted)

        expect(event.confirmed_seats_remaining ).to be_nil
        expect(event.confirmed_seats_remaining?).to eql(true)
      end

      it 'with counted seating' do
        event = create(:event, number_of_seats: 10)

        expect(event.confirmed_seats_remaining ).to eql(10)
        expect(event.confirmed_seats_remaining?).to eql(true)

        order_1 = create(:order, event: event, number_of_seats: 2)
        order_2 = create(:order, event: event, number_of_seats: 3); order_2.update_column(:state, Order.states[:paid])
        order_3 = create(:order, event: event, number_of_seats: 4); order_3.update_column(:state, Order.states[:cancelled])

        # It's memoised for performance...
        #
        expect(event.confirmed_seats_remaining).to eql(10)

        # ...so we have to get a new instance
        #
        event = Event.find(event.id)
        expect(event.confirmed_seats_remaining ).to eql(7) # 10 minus sum of Paid order 2 seats only
        expect(event.confirmed_seats_remaining?).to eql(true)
      end

      it 'will report below zero for over-subscribed events' do
        event = create(:event, number_of_seats: 20)
        order = create(:order, event: event, number_of_seats: 20); order.update_column(:state, Order.states[:paid])
        event.update!(number_of_seats: 8)

        expect(event.confirmed_seats_remaining ).to eql(-12)
        expect(event.confirmed_seats_remaining?).to eql(false)
      end
    end # 'context "#confirmed_seats_remaining" do'

    context "#confirmed_seats_taken" do
      it 'with unrestricted seating' do
        expect(build(:event, :uncounted).confirmed_seats_taken).to be_zero
      end

      it 'with counted seating' do
        event = create(:event, number_of_seats: 10)

        expect(event.confirmed_seats_taken).to be_zero

        order_1 = create(:order, event: event, number_of_seats: 2)
        order_2 = create(:order, event: event, number_of_seats: 3); order_2.update_column(:state, Order.states[:paid])
        order_3 = create(:order, event: event, number_of_seats: 4); order_3.update_column(:state, Order.states[:cancelled])

        # It's memoised for performance...
        #
        expect(event.confirmed_seats_taken).to be_zero

        # ...so we have to get a new instance
        #
        event = Event.find(event.id)
        expect(event.confirmed_seats_taken).to eql(3) # Sum of Paid order 2 seats only
      end

      it 'will report above event number-of-seats for over-subscribed events' do
        event = create(:event, number_of_seats: 20)
        order = create(:order, event: event, number_of_seats: 20); order.update_column(:state, Order.states[:paid])
        event.update!(number_of_seats: 8)

        expect(event.confirmed_seats_taken).to eql(20)
      end
    end # 'context "#confirmed_seats_taken" do'

    context '#get_or_create_stripe_price' do
      it 'when the event has no stripe price attached' do
        mock_prodid    = "product_test_1234"
        mock_priceid   = "price_test_1234"
        mock_event_url = "https://www.example.com/event"
        event          = create(:event)

        expect(Stripe::Product).to receive(:create) do | args |
          expect(args[:name       ]     ).to eql(event.title)
          expect(args[:description]     ).to be_present
          expect(args[:images     ].size).to eql(1)
          expect(args[:images     ][0]  ).to eql(event.product_image_url())
          expect(args[:shippable  ]     ).to eql(false)
          expect(args[:unit_label ]     ).to eql("seat")
          expect(args[:url        ]     ).to eql(mock_event_url)

          double(:product, id: mock_prodid)
        end

        expect(Stripe::Price).to receive(:create) do | args |
          expect(args[:currency   ]).to eql(event.currency)
          expect(args[:unit_amount]).to eql(event.price_per_seat)
          expect(args[:product    ]).to eql(mock_prodid)

          double(:price, id: mock_priceid)
        end

        price = event.get_or_create_stripe_price(with_event_url: mock_event_url)

        expect(price                ).to be_present
        expect(price.event_id       ).to eql(event.id)
        expect(price.stripe_price_id).to eql(mock_priceid)
      end

      it 'when the event has a stripe price attached' do
        price_double = double(:price)
        event        = create(:event)

        expect(event.stripe_price).to be_nil # (self-check)

        allow(event).to receive(:stripe_price).and_return(price_double)

        expect(event.get_or_create_stripe_price(with_event_url: 'n/a')).to eql(price_double)
      end
    end # 'context '#get_or_create_stripe_price' do'
  end # 'context "miscellaneous" do'

  context "utilities" do
    it '#human_state' do
      expect(build(:event).human_state()).to eql("Reservations only (pre-sale)")
    end
  end # 'context "utilities" do'

  context "state machine" do
    context "miscellaneous" do
      it "returns valid events" do
        event           = build(:event)
        purchases_event = Event.aasm(:state).events.find { |e| e.name == :start_public_purchases }
        cancel_event    = Event.aasm(:state).events.find { |e| e.name == :cancel }

        expect(event.state).to eql(Event.states[:presales]) # (self-check)
        expect(event.valid_events()).to match_array([purchases_event, cancel_event])
      end
    end # 'context "miscellaneous" do'

    context "guards" do
      it '#has_reservers?' do
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

      it '#has_[not_]started?' do
        event = create(:event)

        expect(event.has_started?    ).to eql(false)
        expect(event.has_not_started?).to eql(true)

        event.update_column(:starts_at, Time.now - 1.hour)

        expect(event.has_started?    ).to eql(true)
        expect(event.has_not_started?).to eql(false)
      end

      it '#has_[not_]ended?' do
        event = create(:event)

        expect(event.has_ended?    ).to eql(false)
        expect(event.has_not_ended?).to eql(true)

        event.update_column(:starts_at, Time.now - 1.hour)

        expect(event.has_ended?    ).to eql(false)
        expect(event.has_not_ended?).to eql(true)

        event.update_column(:ends_at, Time.now - 5.minutes)

        expect(event.has_ended?    ).to eql(true)
        expect(event.has_not_ended?).to eql(false)
      end
    end # 'context "guards" do'

    context "transitions" do
      before :each do
        @reservers_event = Event.aasm(:state).events.find { |e| e.name == :start_reserver_purchases }
        @public_event    = Event.aasm(:state).events.find { |e| e.name == :start_public_purchases }
        @archive_event   = Event.aasm(:state).events.find { |e| e.name == :archive }
        @cancel_event    = Event.aasm(:state).events.find { |e| e.name == :cancel }

        @event = create(:event)

        expect(@event.state).to eql(Event.states[:presales]) # (self-check)
      end

      context "from presales state" do
        it "with no reservations" do
          expect(@event.valid_events()).to match_array([@public_event, @cancel_event])
        end

        it "with one reservation" do
          order = create(:order, event: @event)
          order.reserve_state!

          ActionMailer::Base.deliveries.clear()

          expect(@event.valid_events()).to match_array([@reservers_event, @public_event, @cancel_event])
        end

        it "once ended" do
          @event.update_columns(starts_at: Time.now - 1.hour, ends_at: Time.now - 30.minutes)

          expect(@event.valid_events()).to match_array([@archive_event, @cancel_event])
        end
      end # 'context "from presales state" do'

      context "from reserver_purchases state" do
        before :each do
          @order = create(:order, event: @event)
          @order.reserve_state!
          @event.start_reserver_purchases_state!
        end

        it "when the event has not yet started" do
          expect(@event.valid_events()).to match_array([@public_event, @cancel_event])
        end

        it "while the event is underway" do
          @event.update_columns(starts_at: Time.now - 1.hour, ends_at: Time.now + 30.minutes)

          # Same as above; allows at-the-door sales, or - and sadly, we have to
          # consider it - "nobody turned up" cancellation
          #
          expect(@event.valid_events()).to match_array([@public_event, @cancel_event])
        end

        it "once the event has ended" do
          @event.update_columns(starts_at: Time.now - 1.hour, ends_at: Time.now - 30.minutes)

          expect(@event.valid_events()).to match_array([@archive_event, @cancel_event])
        end
      end # 'context "from reserver_purchases state" do'

      context "from public_purchases state" do
        before :each do
          @event.start_public_purchases_state!
        end

        it "when the event has not yet started" do
          expect(@event.valid_events()).to match_array([@cancel_event])
        end

        it "while the event is underway" do
          @event.update_columns(starts_at: Time.now - 1.hour, ends_at: Time.now + 30.minutes)

          expect(@event.valid_events()).to match_array([@cancel_event])
        end

        it "once the event has ended" do
          @event.update_columns(starts_at: Time.now - 1.hour, ends_at: Time.now - 30.minutes)

          expect(@event.valid_events()).to match_array([@archive_event, @cancel_event])
        end
      end # 'context "from public_purchases state" do'

      context "from archived state" do
        before :each do
          @event.update_columns(starts_at: Time.now - 1.hour, ends_at: Time.now - 30.minutes)
          @event.archive_state!
        end

        it "allows no other changes" do
          expect(@event.valid_events()).to be_empty
        end
      end # 'context "from archived state" do'

      context "from cancelled state" do
        before :each do
          @event.update_columns(starts_at: Time.now - 1.hour, ends_at: Time.now - 30.minutes)
          @event.cancel_state!
        end

        it "allows no other changes" do
          expect(@event.valid_events()).to be_empty
        end
      end # 'context "from cancelled state" do'

      context "side effects" do
        include Rails.application.routes.url_helpers
        include OrdersHelper

        before :each do
          allow(Hcms.config).to receive(:orders_email).and_return("orders@example.com")
          default_url_options[:host] = 'www.example.com'
        end

        it "starting reserver sales" do
          order_1 = create(:order, event: @event, number_of_seats: 1)
          order_1.reserve_state!

          order_2 = create(:order, event: @event, number_of_seats: 1)
          order_2.reserve_state!

          # No e-mail sent to someone that is getting a free ticket
          #
          order_3 = create(:order, event: @event, number_of_seats: 1, amount_owed: 0)
          order_3.reserve_state!

          # No e-mail sent to someone that somehow paid (e.g. via admin action)
          #
          order_4 = create(:order, event: @event, number_of_seats: 1)
          order_4.update_column(:state, Order.states[:paid])

          perform_enqueued_jobs()
          ActionMailer::Base.deliveries.clear()

          @event.start_reserver_purchases_state!

          messages = spechelp_decode_multipart(count: 2)

          [order_1, order_2].each do | order |
            to_customer = spechelper_find_in_decoded(messages, to: order.email)

            expect(to_customer.email.from   ).to eql(["orders@example.com"])
            expect(to_customer.email.subject).to eql("It's time to confirm your booking for \"#{@event.title}\"")

            expect(to_customer.text).to include(@event.title.upcase)
            expect(to_customer.text).to include("If you still wish to attend")
            expect(to_customer.text).to include(ordershelp_magic_link(order))

            expect(to_customer.html).to include(@event.title)
            expect(to_customer.html).to include("If you still wish to attend")
            expect(to_customer.html).to include(ordershelp_magic_link(order))
          end
        end

        it "starting public sales" do
          order_1 = create(:order, event: @event, number_of_seats: 1)
          order_1.reserve_state!

          order_2 = create(:order, event: @event, number_of_seats: 1)
          order_2.reserve_state!

          # No e-mail sent to someone that is getting a free ticket
          #
          order_3 = create(:order, event: @event, number_of_seats: 1, amount_owed: 0)
          order_3.reserve_state!

          # No e-mail sent to someone that somehow paid (e.g. via admin action)
          #
          order_4 = create(:order, event: @event, number_of_seats: 1)
          order_4.update_column(:state, Order.states[:paid])

          perform_enqueued_jobs()
          ActionMailer::Base.deliveries.clear()

          @event.start_public_purchases_state!

          messages = spechelp_decode_multipart(count: 2)

          [order_1, order_2, order_3, order_4].map(&:reload)

          expect(order_1.state).to eql(Order.states[:new ]) # Reservation cancelled
          expect(order_2.state).to eql(Order.states[:new ]) # Reservation cancelled
          expect(order_3.state).to eql(Order.states[:paid]) # Auto-marked as paid
          expect(order_4.state).to eql(Order.states[:paid]) # No change

          [order_1, order_2].each do | order |
            to_customer = spechelper_find_in_decoded(messages, to: order.email)

            expect(to_customer.email.from   ).to eql(["orders@example.com"])
            expect(to_customer.email.subject).to eql("General sales now available for \"#{@event.title}\"")

            expect(to_customer.text).to include(@event.title.upcase)
            expect(to_customer.text).to include("Reservations have now expired")
            expect(to_customer.text).to include(ordershelp_magic_link(order))

            expect(to_customer.html).to include(@event.title)
            expect(to_customer.html).to include("Reservations have now expired")
            expect(to_customer.html).to include(ordershelp_magic_link(order))
          end
        end

        shared_examples "a working cancellation state machine" do
          it "which sends e-mails and updates order states" do
            order_1 = create(:order, event: @event, number_of_seats: 1)
            order_1.reserve_state!

            order_2 = create(:order, event: @event, number_of_seats: 1)
            order_2.reserve_state!

            order_3 = create(:order, event: @event, number_of_seats: 1, amount_owed: 0)
            order_3.reserve_state!

            # Refund e-mail sent for order paid (probably via admin action)
            #
            order_4 = create(:order, event: @event, number_of_seats: 1)
            order_4.update_column(:state, Order.states[:paid])

            # This order is a work-in-progress.
            #
            order_5 = create(:order, event: @event, number_of_seats: 1)

            if @advance_to_reserver_purchases_first
              @event.start_reserver_purchases_state!
            end

            if @advance_to_public_purchases_first
              @event.start_public_purchases_state!
            end

            perform_enqueued_jobs()
            ActionMailer::Base.deliveries.clear()

            if @expect_event_cancellation_error
              expect { @event.cancel_state! }.to raise_error(RuntimeError)
            else
              @event.cancel_state!
            end

            # - No notification for the "new" state order customer
            # - Refund notification for non-zero amount paid order's customer
            # - Cancel notifications for the other order customers
            # - No admin cancellation notifications, since the event itself was
            #   cancelled
            #
            messages = spechelp_decode_multipart(count: 4)

            [order_1, order_2, order_3].each do | order |
              to_customer = messages.find { |m| m.email.to.first == order.email }

              expect(to_customer).to be_present
              expect(to_customer.email.subject).to include("Confirmation of cancellation")

              expect(to_customer.text).to include(@event.title.upcase)
              expect(to_customer.text).to include("Unfortunately, this event has been cancelled.")

              expect(to_customer.html).to include(@event.title)
              expect(to_customer.html).to include("Unfortunately, this event has been cancelled.")

              expect(order.reload().state_cancelled?).to eql(true)
            end

            to_customer = messages.find { |m| m.email.to.first == order_4.email }
            total       = spechelp_format_money(order_4.amount_owed, @event.currency)

            expect(to_customer).to be_present
            expect(to_customer.email.subject).to include("Confirmation of refund")

            expect(to_customer.text).to include(@event.title.upcase)
            expect(to_customer.text).to include("Unfortunately, this event has been cancelled.") # (sic.)
            expect(to_customer.text).to include("#{total} has been refunded.")

            expect(to_customer.html).to include(@event.title)
            expect(to_customer.html).to include("Unfortunately, this event has been cancelled.") # (sic.)
            expect(to_customer.html).to include("#{total}\n  has been refunded.")

            expect(order_4.reload().state_refunded?).to eql(true)
            expect(order_5.reload().state_cancelled?).to eql(true)
          end
        end # 'shared_examples "a working state machine" do'

        context "cancelling from presales without a Stripe price present" do
          it_behaves_like "a working cancellation state machine"
        end # 'context "without a Stripe price present" do'

        context "cancelling from presales with a Stripe price present and no errors from Stripe" do
          before :each do
            expect_stripe_to_be_made_inactive_via(@event)
          end

          it_behaves_like "a working cancellation state machine"
        end

        context "cancelling from presales with a Stripe price present and an error from Stripe" do
          before :each do
            expect_stripe_to_be_made_inactive_via(@event, simulated_failure: true)
            @expect_event_cancellation_error = true
          end

          it_behaves_like "a working cancellation state machine"
        end

        context "cancelling from presales when inside the refunds window" do
          before :each do
            allow(Hcms.config).to receive(:no_refunds_window).and_return(2) # (2 days)

            @event.starts_at = Time.now + 1.day
            @event.ends_at   = Time.now + 1.day + 3.hours
            @event.save!
          end

          it_behaves_like "a working cancellation state machine"
        end

        context "cancelling from the reserver purchases state" do
          before :each do
            @advance_to_reserver_purchases_first = true
          end

          it_behaves_like "a working cancellation state machine"
        end

        # This is bespoke compared to the above use of shared examples, because
        # once we go to public sales, presales are dropped into a "new" state,
        # so the e-mail expectations no longer work. It's simpler to test anew.
        #
        context "cancelling from the public purchases state" do
          shared_examples "a working from-public-purchase state machine" do
            it "sends e-mails and updates order states" do
              @event.start_public_purchases_state!

              # Non-zero amount, so gets 'refunded due to cancellation'.
              #
              order_1 = create(:order, event: @event, number_of_seats: 1)
              order_1.pay_state!

              # Paid but free, so gets 'event cancelled' as an e-mail but the
              # internal state is still 'refunded'.
              #
              order_2 = create(:order, event: @event, number_of_seats: 1, amount_owed: 0)
              order_2.pay_state!

              # This order is a work-in-progress. No e-mails should be sent.
              #
              order_3 = create(:order, event: @event, number_of_seats: 1)

              perform_enqueued_jobs()
              ActionMailer::Base.deliveries.clear()

              @event.cancel_state!

              expect(order_1.reload().state_refunded? ).to eql(true)
              expect(order_2.reload().state_refunded? ).to eql(true)
              expect(order_3.reload().state_cancelled?).to eql(true)

              messages    = spechelp_decode_multipart(count: 2)
              to_customer = messages.find { |m| m.email.to.first == order_1.email }
              total       = spechelp_format_money(order_1.amount_owed, @event.currency)

              expect(to_customer).to be_present
              expect(to_customer.email.subject).to include("Confirmation of refund")

              expect(to_customer.text).to include(@event.title.upcase)
              expect(to_customer.text).to include("Unfortunately, this event has been cancelled.") # (sic.)
              expect(to_customer.text).to include("#{total} has been refunded.")

              expect(to_customer.html).to include(@event.title)
              expect(to_customer.html).to include("Unfortunately, this event has been cancelled.") # (sic.)
              expect(to_customer.html).to include("#{total}\n  has been refunded.")

              to_customer = messages.find { |m| m.email.to.first == order_2.email }

              expect(to_customer).to be_present
              expect(to_customer.email.subject).to include("Confirmation of cancellation")

              expect(to_customer.text).to include(@event.title.upcase)
              expect(to_customer.text).to include("Unfortunately, this event has been cancelled.")

              expect(to_customer.html).to include(@event.title)
              expect(to_customer.html).to include("Unfortunately, this event has been cancelled.")
            end
          end # 'shared_examples "a working from-public-purchase state machine"'

          context "outside the no-refunds window" do
            it_behaves_like "a working from-public-purchase state machine"
          end # 'context "outside the no-refunds window" do'

          context "inside the no-refunds window" do
            before :each do
              allow(Hcms.config).to receive(:no_refunds_window).and_return(2) # (2 days)

              @event.starts_at = Time.now + 1.day
              @event.ends_at   = Time.now + 1.day + 3.hours
              @event.save!
            end

            it_behaves_like "a working from-public-purchase state machine"
          end # 'context "inside the no-refunds window" do'
        end

        # Archiving has a primary guard of "has ended". While an admin might
        # want to manually archive before that time, this is presently not
        # supported in order to keep things simple (last-minute cancellations,
        # purchase requests etc. could all happen and would be a terrible mess
        # to try and sort out if the event had reached an archived state).
        #
        # Since the event has finished, we don't send any further e-mails.
        #
        shared_examples "a working archiver" do
          it "sends no messages, but makes the related Stripe product inactive" do
            order_1 = create(:order, event: @event, number_of_seats: 1)
            order_1.reserve_state!

            order_2 = create(:order, event: @event, number_of_seats: 1)
            order_2.reserve_state!

            # This is a free seat, but we still expect the user to confirm their
            # reservation by going through the special case "free item" checkout
            # flow.
            #
            order_3 = create(:order, event: @event, number_of_seats: 1, amount_owed: 0)
            order_3.reserve_state!

            order_4 = create(:order, event: @event, number_of_seats: 1)
            order_4.update_column(:state, Order.states[:paid])

            perform_enqueued_jobs()
            ActionMailer::Base.deliveries.clear()

            @event.starts_at = Time.now - 3.hours - 5.minutes
            @event.ends_at   = Time.now - 5.minutes
            @event.archive_state!

            messages = spechelp_decode_multipart(count: 0)

            expect(messages).to be_empty

            [order_1, order_2, order_3, order_4].map(&:reload)

            expect(order_1.state).to eql(Order.states[:reserved])
            expect(order_2.state).to eql(Order.states[:reserved])
            expect(order_3.state).to eql(Order.states[:reserved]) # NOT auto-marked as paid; user never confirmed reservation
            expect(order_4.state).to eql(Order.states[:paid])
          end
        end # 'shared_examples "a working archiver" do'

        context "archiving a completed event" do
          before :each do
            expect_stripe_to_be_made_inactive_via(@event)
          end

          it_behaves_like "a working archiver"
        end # 'context "archiving a completed event" do'

        context "archiving an event that never got a Stripe product added" do
          before :each do
            expect(@event.stripe_price).to be_nil # (event factory self-check)
          end # 'context "archiving an event that never got a Stripe product added" do'

          it_behaves_like "a working archiver"
        end

        context "on-archive actions" do
          before :each do
            @event.starts_at = Time.now - 3.hours - 5.minutes
            @event.ends_at   = Time.now - 5.minutes
          end

          it "makes no changes with 'keep'" do
            @event.on_archive_action = Event.on_archive_actions[:keep]

            expect {
              @event.archive_state!
            }.to_not change { Article.count + Revision.count }

            @event.reload

            expect(@event.hidden).to eql(false)
          end

          it "sets the 'hidden' flag with 'hide'" do
            @event.on_archive_action = Event.on_archive_actions[:hide]

            expect {
              @event.archive_state!
            }.to_not change { Article.count + Revision.count }

            @event.reload

            expect(@event.hidden).to eql(true)
          end

          it "creates a copied blog post and hides the original with 'move'" do
            page = create(:page, :blog)

            expect(page.articles.count).to be_zero # (self-check)

            @event.on_archive_action = Event.on_archive_actions[:move]
            @event.on_archive_params = { blog_id: page.id }

            expect {
              @event.archive_state!
            }.to change { Article.count + Revision.count }.by(2)

            expect(page.articles.count).to eql(1)

            article = page.articles.first

            expect(article.title           ).to eql(@event.title           )
            expect(article.navigation_title).to eql(@event.navigation_title)
            expect(article.summary         ).to eql(@event.summary         )
            expect(article.body            ).to eql(@event.body            )
            expect(article.created_at      ).to eql(@event.starts_at       )
            expect(article.updated_at      ).to eql(@event.starts_at       )
            expect(article.created_at      ).to eql(@event.starts_at       )

            expect(article.article_hero_image).to be_present

            a_path = Rails.root.join("public", article.article_hero_image.url[1..])
            e_path = Rails.root.join("public", @event.event_hero_image.url[1..])

            a_digest = Digest::MD5.hexdigest(File.read(a_path))
            e_digest = Digest::MD5.hexdigest(File.read(e_path))

            expect(a_digest).to eql(e_digest)
          end

          it "handles a missing blog on-archive" do
            @event.on_archive_action = Event.on_archive_actions[:move]
            @event.on_archive_params = { blog_id: 0 }

            expect {
              @event.archive_state!
            }.to_not change { Article.count + Revision.count }

            @event.reload

            expect(@event.hidden).to eql(true)
          end
        end # 'context "on-archive actions" do'
      end # 'context "side effects" do'
    end # 'context "transitions" do'
  end # 'context "state machine" do

  context "when destroyed" do
    it "makes an associated Stripe price inactive" do
      event = create(:event)

      expect_stripe_to_be_made_inactive_via(event)

      event.destroy!

      expect(Event.find_by_id(event.id)).to be_nil
    end
  end
end
