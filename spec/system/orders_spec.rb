require "spec_helper.rb"

RSpec.describe "Orders" do
  include OrdersHelper

  before :each do
    allow_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return("")

    allow(Hcms.config).to receive(:orders_email).and_return("orders@example.com")
    allow(Hcms.config).to receive(:site_name   ).and_return("Site Under Test")

    @page = create(:page, :events)
    @page.revisions.first.update!(published: true)

    @event = create(:event, page: @page)
    @event.revisions.first.update!(published: true)
  end

  shared_examples "a form validator" do
    it "which validates the form" do
      visit new_page_event_order_path(@page.slug, @event.slug)

      click_on("Next")

      expect(page).to have_css(".field_error_messages", text: "Name must be provided")
      expect(page).to have_css(".field_error_messages", text: "E-mail address must be provided")
      expect(page).to have_css(".field_error_messages", text: "Number of seats must be provided")

      fill_in("order_name", with: "Fred Flinstone")

      click_on("Next")

      expect(page).to     have_field("order_name", with: "Fred Flinstone")
      expect(page).to_not have_css(".field_error_messages", text: "Name must be provided")

      fill_in("order_number_of_seats", with: @event.number_of_seats + 1)

      click_on("Next")

      expect(page).to have_css(".field_error_messages", text: "Number of seats requested is too high - only #{@event.number_of_seats} left")
    end

    it "which rejects suspected robots" do
      expect_any_instance_of(OrdersController).to receive(:verify_recaptcha).once.and_return(false)

      visit new_page_event_order_path(@page.slug, @event.slug)

      name  = "Fred Flintstone"
      email = "fred@example.com"
      phone = "+64 021 000 000"
      seats = 2

      fill_in("order_name",            with: name)
      fill_in("order_email",           with: email)
      fill_in("order_phone_number",    with: phone)
      fill_in("order_number_of_seats", with: seats)

      click_on("Next")

      expect(Order.count).to eql(0)
      expect(page).to have_text("Sorry, the anti-robots checker wasn't happy")
    end
  end

  context "presales" do
    it_behaves_like "a form validator"

    it "accepts a reservation and sends confirmation e-mails to both parties" do
      visit new_page_event_order_path(@page.slug, @event.slug)

      name  = "Fred Flintstone"
      email = "fred@example.com"
      phone = "+64 021 000 000"
      seats = 2

      fill_in("order_name",            with: name)
      fill_in("order_email",           with: email)
      fill_in("order_phone_number",    with: phone)
      fill_in("order_number_of_seats", with: seats)

      click_on("Next")

      expect(Order.count).to eql(1)

      expect(Order.first.state          ).to eql("new")
      expect(Order.first.name           ).to eql(name)
      expect(Order.first.email          ).to eql(email)
      expect(Order.first.phone_number   ).to eql("021 000 000")
      expect(Order.first.number_of_seats).to eql(seats)
      expect(Order.first.amount_owed    ).to eql(@event.price_per_seat * seats)

      per_seat = spechelp_format_money(@event.price_per_seat,         @event.currency)
      total    = spechelp_format_money(@event.price_per_seat * seats, @event.currency)

      expect(page).to have_text("Please confirm your reservation")
      expect(page).to have_text(@event.title)
      expect(page).to have_text(@event.location)
      expect(page).to have_text("#{seats} × #{per_seat}")
      expect(page).to have_text("#{total}")

      click_on("Confirm reservation")

      expect(Order.count).to eql(1)
      expect(Order.first.state).to eql("reserved")
      expect(page).to have_text("Thanks, your reservation has been made")

      messages = spechelp_decode_multipart(count: 2)

      to_customer = spechelper_find_in_decoded(messages, to: email)
      to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

      expect(to_customer).to be_present
      expect(to_admin   ).to be_present

      expect(to_customer.email.from   ).to eql(["orders@example.com"])
      expect(to_customer.email.subject).to eql("Reservation confirmed for \"#{@event.title}\"")

      expect(to_customer.text).to include(@event.title.upcase)
      expect(to_customer.text).to include(total)
      expect(to_customer.text).to include(ordershelp_magic_link(Order.first))

      expect(to_customer.html).to include(@event.title)
      expect(to_customer.html).to include(total)
      expect(to_customer.html).to have_link("Manage order", href: ordershelp_magic_link(Order.first))

      expect(to_admin.email.from   ).to eql(["orders@example.com"])
      expect(to_admin.email.subject).to eql("[Site Under Test] New reservation from #{Order.first.name}")

      expect(to_admin.text).to include(name)
      expect(to_admin.text).to include(email)
      expect(to_admin.text).to include("021 000 000")

      expect(to_admin.html).to have_css("dd", text: name)
      expect(to_admin.html).to have_css("dd", text: seats)
      spechelp_check_mailto(
        html:    to_admin.html,
        email:   email,
        subject: "Your reservation for \"#{@event.title}\""
      )
      spechelp_check_tel(
        html:  to_admin.html,
        phone: "021 000 000"
      )
      expect(to_admin.html).to have_link(
        "Manage order",
        href: admin_page_event_order_url(page_id: @event.page.slug, event_id: @event.slug, id: Order.first.id)
      )
      expect(to_admin.html).to have_link(
        "here", # ...as in, "You can find a list of all orders <here>"
        href: admin_page_event_orders_url(page_id: @event.page.slug, event_id: @event.slug)
      )
    end

    it "lets the user cancel" do
      visit new_page_event_order_path(@page.slug, @event.slug)

      name  = "Fred Flintstone"
      email = "fred@example.com"
      phone = "+64 021 000 000"
      seats = 2

      fill_in("order_name",            with: name)
      fill_in("order_email",           with: email)
      fill_in("order_phone_number",    with: phone)
      fill_in("order_number_of_seats", with: seats)

      click_on("Next")

      expect(Order.count).to eql(1)
      expect(Order.first.state).to eql("new")
      expect(page).to have_text("Please confirm your reservation")

      click_on("Cancel reservation")

      expect(Order.count).to eql(0)
      expect(page).to have_text("OK, that's cancelled")
    end

    it "lets the user amend their details" do
      visit new_page_event_order_path(@page.slug, @event.slug)

      name  = "Fred Flintstone"
      email = "fred@example.com"
      phone = "+64 021 000 000"
      seats = 2

      fill_in("order_name",            with: name)
      fill_in("order_email",           with: email)
      fill_in("order_phone_number",    with: phone)
      fill_in("order_number_of_seats", with: seats)

      click_on("Next")

      expect(Order.count).to eql(1)
      expect(Order.first.state).to eql("new")
      expect(page).to have_text("Please confirm your reservation")

      click_on("Amend details")

      fill_in("order_name",            with: "2-" + name)
      fill_in("order_email",           with: "2-" + email)
      fill_in("order_phone_number",    with: "")
      fill_in("order_number_of_seats", with: 2 + seats)

      click_on("Next")

      expect(Order.count).to eql(1)

      expect(Order.first.state          ).to eql("new")
      expect(Order.first.name           ).to eql("2-" + name)
      expect(Order.first.email          ).to eql("2-" + email)
      expect(Order.first.phone_number   ).to eql("")
      expect(Order.first.number_of_seats).to eql(2 + seats)
      expect(Order.first.amount_owed    ).to eql(@event.price_per_seat * (2 + seats))

      click_on("Confirm reservation")

      expect(Order.count).to eql(1)
      expect(Order.first.state).to eql("reserved")
      expect(page).to have_text("Thanks, your reservation has been made")

      messages = spechelp_decode_multipart(count: 2)

      to_customer = spechelper_find_in_decoded(messages, to: "2-" + email)
      to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

      expect(to_customer).to be_present
      expect(to_admin   ).to be_present
    end
  end # 'context "presales" do'

  context "public sales" do
    before :each do
      @event.start_public_purchases_state!
    end

    context "free events" do
      before :each do
        @event.update_column(:price_per_seat, 0)
      end

      it_behaves_like "a form validator"

      it "can be booked with a confirmation e-mail sent to both parties" do
        visit new_page_event_order_path(@page.slug, @event.slug)

        name  = "Fred Flintstone"
        email = "fred@example.com"
        phone = "+64 021 000 000"
        seats = 2

        fill_in("order_name",            with: name)
        fill_in("order_email",           with: email)
        fill_in("order_phone_number",    with: phone)
        fill_in("order_number_of_seats", with: seats)

        click_on("Next")

        expect(Order.count).to eql(1)

        expect(Order.first.state          ).to eql("paid")
        expect(Order.first.name           ).to eql(name)
        expect(Order.first.email          ).to eql(email)
        expect(Order.first.phone_number   ).to eql("021 000 000")
        expect(Order.first.number_of_seats).to eql(seats)
        expect(Order.first.amount_owed    ).to eql(0)

        expect(page).to have_text("Thanks, your booking is confirmed")

        messages = spechelp_decode_multipart(count: 2)

        to_customer = spechelper_find_in_decoded(messages, to: email)
        to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

        expect(to_customer).to be_present
        expect(to_admin   ).to be_present

        expect(to_customer.email.from   ).to eql(["orders@example.com"])
        expect(to_customer.email.subject).to eql("Booking confirmed for \"#{@event.title}\"")

        expect(to_customer.text).to include(@event.title.upcase)
        expect(to_customer.text).to include(ordershelp_magic_link(Order.first))

        expect(to_customer.html).to include(@event.title)
        expect(to_customer.html).to have_link("Manage order", href: ordershelp_magic_link(Order.first))

        expect(to_admin.email.from   ).to eql(["orders@example.com"])
        expect(to_admin.email.subject).to eql("[Site Under Test] New paid booking from #{Order.first.name}")

        expect(to_admin.text).to include(name)
        expect(to_admin.text).to include(email)
        expect(to_admin.text).to include("021 000 000")

        expect(to_admin.html).to have_css("dd", text: name)
        expect(to_admin.html).to have_css("dd", text: seats)
        spechelp_check_mailto(
          html:    to_admin.html,
          email:   email,
          subject: "Your booking for \"#{@event.title}\""
        )
        spechelp_check_tel(
          html:  to_admin.html,
          phone: "021 000 000"
        )
        expect(to_admin.html).to have_link(
          "Manage order",
          href: admin_page_event_order_url(page_id: @event.page.slug, event_id: @event.slug, id: Order.first.id)
        )
        expect(to_admin.html).to have_link(
          "here", # ...as in, "You can find a list of all orders <here>"
          href: admin_page_event_orders_url(page_id: @event.page.slug, event_id: @event.slug)
        )
      end
    end # 'context "free events" do'

    context "paid events" do
      it_behaves_like "a form validator"

      it "accepts a booking with successful payment and sends confirmation e-mails to both parties" do
        visit new_page_event_order_path(@page.slug, @event.slug)

        name  = "Fred Flintstone"
        email = "fred@example.com"
        phone = "+64 021 000 000"
        seats = 2

        fill_in("order_name",            with: name)
        fill_in("order_email",           with: email)
        fill_in("order_phone_number",    with: phone)
        fill_in("order_number_of_seats", with: seats)

        click_on("Next")

        expect(Order.count).to eql(1)

        expect(Order.first.state          ).to eql("new")
        expect(Order.first.name           ).to eql(name)
        expect(Order.first.email          ).to eql(email)
        expect(Order.first.phone_number   ).to eql("021 000 000")
        expect(Order.first.number_of_seats).to eql(seats)
        expect(Order.first.amount_owed    ).to eql(@event.price_per_seat * seats)

        per_seat = spechelp_format_money(@event.price_per_seat,         @event.currency)
        total    = spechelp_format_money(@event.price_per_seat * seats, @event.currency)

        expect(page).to have_text("Please check the details of your booking")
        expect(page).to have_text(@event.title)
        expect(page).to have_text(@event.location)
        expect(page).to have_text("#{seats} × #{per_seat}")
        expect(page).to have_text("#{total}")

        mock_prodid  = "product_test_1234"
        mock_priceid = "price_test_1234"
        mock_csid    = "cs_test_1234"
        mock_payint  = "pi_test_1234"

        expect(Stripe::Product).to receive(:create).once do | args |
          expect(args[:name]).to eql(@event.title)

          double(id: mock_prodid)
        end

        expect(Stripe::Price).to receive(:create).once do | args |
          expect(args[:currency   ]).to eql(@event.currency)
          expect(args[:unit_amount]).to eql(@event.price_per_seat)
          expect(args[:product    ]).to eql(mock_prodid)

          double(id: mock_priceid)
        end

        expect(Stripe::Checkout::Session).to receive(:create).once do | args |
          expect(args[:mode]).to eql("payment")
          expect(args[:success_url]).to include("manage_order")
          expect(args[:cancel_url ]).to include("manage_order")
          expect(args[:success_url]).to end_with("stripe_payment_succeeded?csid={CHECKOUT_SESSION_ID}")
          expect(args[:cancel_url ]).to end_with("stripe_payment_cancelled?csid={CHECKOUT_SESSION_ID}")

          expect(args[:line_items].size ).to eql(1)
          expect(args[:line_items].first).to eql({price: mock_priceid, quantity: 2})

          double(url: args[:success_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
        end

        expect(Stripe::Checkout::Session).to receive(:retrieve).with(mock_csid) do
          double(payment_intent: mock_payint)
        end

        click_on("Pay now")

        expect(StripePrice.count).to eql(1)
        expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
        expect(StripePayment.count).to eql(1)
        expect(StripePayment.first.stripe_payment_intent).to eql(mock_payint)
        expect(Order.count).to eql(1)
        expect(Order.first.state).to eql("paid")
        expect(page).to have_text("Thanks, your booking is confirmed")

        messages = spechelp_decode_multipart(count: 2)

        to_customer = spechelper_find_in_decoded(messages, to: email)
        to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

        expect(to_customer).to be_present
        expect(to_admin   ).to be_present

        expect(to_customer.email.from   ).to eql(["orders@example.com"])
        expect(to_customer.email.subject).to eql("Booking confirmed for \"#{@event.title}\"")

        expect(to_customer.text).to include(@event.title.upcase)
        expect(to_customer.text).to include(total)
        expect(to_customer.text).to include(ordershelp_magic_link(Order.first))

        expect(to_customer.html).to include(@event.title)
        expect(to_customer.html).to include(total)
        expect(to_customer.html).to have_link("Manage order", href: ordershelp_magic_link(Order.first))

        expect(to_admin.email.from   ).to eql(["orders@example.com"])
        expect(to_admin.email.subject).to eql("[Site Under Test] New paid booking from #{Order.first.name}")

        expect(to_admin.text).to include(name)
        expect(to_admin.text).to include(email)
        expect(to_admin.text).to include("021 000 000")

        expect(to_admin.html).to have_css("dd", text: name)
        expect(to_admin.html).to have_css("dd", text: seats)
        spechelp_check_mailto(
          html:    to_admin.html,
          email:   email,
          subject: "Your booking for \"#{@event.title}\""
        )
        spechelp_check_tel(
          html:  to_admin.html,
          phone: "021 000 000"
        )
        expect(to_admin.html).to have_link(
          "Manage order",
          href: admin_page_event_order_url(page_id: @event.page.slug, event_id: @event.slug, id: Order.first.id)
        )
        expect(to_admin.html).to have_link(
          "here", # ...as in, "You can find a list of all orders <here>"
          href: admin_page_event_orders_url(page_id: @event.page.slug, event_id: @event.slug)
        )
      end

      it "handles the user cancelling from within Stripe and confirming" do
        visit new_page_event_order_path(@page.slug, @event.slug)

        name  = "Fred Flintstone"
        email = "fred@example.com"
        phone = "+64 021 000 000"
        seats = 2

        fill_in("order_name",            with: name)
        fill_in("order_email",           with: email)
        fill_in("order_phone_number",    with: phone)
        fill_in("order_number_of_seats", with: seats)

        click_on("Next")

        expect(Order.count).to eql(1)
        expect(page).to have_text("Please check the details of your booking")

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

        expect(Order.count).to eql(1)
        expect(Order.first.state).to eql("new")
        expect(page).to have_text("Please confirm cancellation")

        click_on("Cancel")

        expect(Order.count).to eql(1)
        expect(Order.first.state).to eql("cancelled")
        expect(page).to have_text("OK, that's cancelled")
      end

      it "handles the user cancelling from within Stripe but then changing their mind and paying" do
        visit new_page_event_order_path(@page.slug, @event.slug)

        name  = "Fred Flintstone"
        email = "fred@example.com"
        phone = "+64 021 000 000"
        seats = 2

        fill_in("order_name",            with: name)
        fill_in("order_email",           with: email)
        fill_in("order_phone_number",    with: phone)
        fill_in("order_number_of_seats", with: seats)

        click_on("Next")

        expect(Order.count).to eql(1)
        expect(page).to have_text("Please check the details of your booking")

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

        expect(Order.count).to eql(1)
        expect(Order.first.state).to eql("new")
        expect(page).to have_text("Please confirm cancellation")

        expect(Stripe::Checkout::Session).to receive(:create).once do | args |
          double(url: args[:success_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
        end

        expect(Stripe::Checkout::Session).to receive(:retrieve).with(mock_csid) do
          double(payment_intent: mock_payint)
        end

        click_on("Pay now")

        expect(StripePrice.count).to eql(1)
        expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
        expect(StripePayment.count).to eql(1)
        expect(StripePayment.first.stripe_payment_intent).to eql(mock_payint)
        expect(Order.count).to eql(1)
        expect(Order.first.state).to eql("paid")
        expect(page).to have_text("Thanks, your booking is confirmed")

        messages = spechelp_decode_multipart(count: 2)

        to_customer = spechelper_find_in_decoded(messages, to: email)
        to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

        expect(to_customer).to be_present
        expect(to_admin   ).to be_present
      end

      context "handle failures" do
        before :each do
          visit new_page_event_order_path(@page.slug, @event.slug)

          name  = "Fred Flintstone"
          email = "fred@example.com"
          phone = "+64 021 000 000"
          seats = 2

          fill_in("order_name",            with: name)
          fill_in("order_email",           with: email)
          fill_in("order_phone_number",    with: phone)
          fill_in("order_number_of_seats", with: seats)

          click_on("Next")

          expect(Order.count).to eql(1)
          expect(page).to have_text("Please check the details of your booking")
        end

        # This is probably the most serious of all error cases, since it means
        # that "our side" has not recorded payment but money has almost
        # certainly been taken from the customer by Stripe.
        #
        it "of on-success attempt to update order state" do
          visit new_page_event_order_path(@page.slug, @event.slug)

          name  = "Fred Flintstone"
          email = "fred@example.com"
          phone = "+64 021 000 000"
          seats = 2

          fill_in("order_name",            with: name)
          fill_in("order_email",           with: email)
          fill_in("order_phone_number",    with: phone)
          fill_in("order_number_of_seats", with: seats)

          click_on("Next")

          expect(Order.count).to eql(1)
          expect(Order.first.state ).to eql("new")

          expect(page).to have_text("Please check the details of your booking")

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

          expect(Order).to receive(:lock) { raise "An error" }

          captured_message = nil

          expect(Sentry).to receive(:capture_exception).with(kind_of(RuntimeError), extra: { order_id: Order.first.id })
          expect(Sentry).to receive(:capture_message) do | message, **args |
            captured_message = message
            expect(message).to include("Payment made but website-side order update failed")
            order_id = args[:extra][:order_id]
            expect(Order.first.id).to eql(order_id)
            expect(captured_message).to include(order_id)
          end

          click_on("Pay now")

          expect(StripePrice.count).to eql(1)
          expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
          expect(StripePayment.count).to eql(0)
          expect(Order.count).to eql(1)
          expect(Order.first.state).to eql("new") # :-(
          expect(captured_message).to include(Order.first.id) # Proves that by this point, it's still the same Order

          # We *don't tell the customer* since our best guess is that Stripe
          # did succeed, since it invoked the on-success URL. This is our mess
          # to sort out, so we're mostly interested in the Sentry and admin
          # e-mail alerts.
          #
          expect(page).to have_text("Thanks, your booking is confirmed")

          to_admin = spechelp_decode_multipart()

          expect(to_admin.email.from   ).to eql(["orders@example.com"])
          expect(to_admin.email.to     ).to eql(["orders@example.com"])
          expect(to_admin.email.subject).to eql("[Site Under Test] PROBLEMATIC ORDER ALERT")

          expect(to_admin.text).to include(name)
          expect(to_admin.text).to include(email)
          expect(to_admin.text).to include("021 000 000")
          expect(to_admin.text).to include("Please reconcile payment records")

          expect(to_admin.html).to include("Please reconcile payment records")
          expect(to_admin.html).to have_css("dd", text: name)
          expect(to_admin.html).to have_css("dd", text: seats)
          spechelp_check_mailto(
            html:    to_admin.html,
            email:   email,
            subject: "Your reservation for \"#{@event.title}\"" # (sic.) - best the system can do; local state is not "paid"
          )
          spechelp_check_tel(
            html:  to_admin.html,
            phone: "021 000 000"
          )
          expect(to_admin.html).to have_link(
            "Manage order",
            href: admin_page_event_order_url(page_id: @event.page.slug, event_id: @event.slug, id: Order.first.id)
          )
          expect(to_admin.html).to have_link(
            "here", # ...as in, "You can find a list of all orders <here>"
            href: admin_page_event_orders_url(page_id: @event.page.slug, event_id: @event.slug)
          )
        end

        it "of on-success Stripe transaction ('payment intent') ID retrieval" do
          visit new_page_event_order_path(@page.slug, @event.slug)

          name  = "Fred Flintstone"
          email = "fred@example.com"
          phone = "+64 021 000 000"
          seats = 2

          fill_in("order_name",            with: name)
          fill_in("order_email",           with: email)
          fill_in("order_phone_number",    with: phone)
          fill_in("order_number_of_seats", with: seats)

          click_on("Next")

          expect(Order.count).to eql(1)
          expect(Order.first.state ).to eql("new")

          expect(page).to have_text("Please check the details of your booking")

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
          expect(Sentry).to receive(:capture_exception).with(kind_of(RuntimeError), extra: { order_id: Order.first.id })

          click_on("Pay now")

          # The Sentry call is expected - see above - and no StripePayment is
          # then recorded, but everything else should still work.
          #
          expect(StripePrice.count).to eql(1)
          expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
          expect(StripePayment.count).to eql(0)
          expect(Order.count).to eql(1)
          expect(Order.first.state).to eql("paid")
          expect(page).to have_text("Thanks, your booking is confirmed")

          messages = spechelp_decode_multipart(count: 2)

          to_customer = spechelper_find_in_decoded(messages, to: email)
          to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")

          expect(to_customer).to be_present
          expect(to_admin   ).to be_present
        end

        it "of Stripe product creation" do
          expect(Stripe::Product).to receive(:create) { raise Stripe::StripeError.new("Failed") }
          expect(Sentry).to receive(:capture_exception).with(kind_of(Stripe::StripeError), extra: { order_id: Order.first.id })

          click_on("Pay now")

          expect(StripePrice.count).to eql(0)
          expect(Order.count).to eql(1)
          expect(Order.first.state).to eql("new")
          expect(page).to have_text("Sorry, there was a problem trying to talk to the payment provider")
        end

        it "of Stripe price creation" do
          expect(Stripe::Product).to receive(:create).once.and_return double(id: "product-1234")
          expect(Stripe::Price).to receive(:create) { raise Stripe::StripeError.new("Failed") }
          expect(Sentry).to receive(:capture_exception).with(kind_of(Stripe::StripeError), extra: { order_id: Order.first.id })

          click_on("Pay now")

          expect(StripePrice.count).to eql(0)
          expect(Order.count).to eql(1)
          expect(Order.first.state).to eql("new")
          expect(page).to have_text("Sorry, there was a problem trying to talk to the payment provider")
        end

        it "of Stripe checkout session creation" do
          expect(Stripe::Product).to receive(:create).once.and_return double(id: "product-1234")
          expect(Stripe::Price).to receive(:create).once.and_return double(id: "price-1234")
          expect(Stripe::Checkout::Session).to receive(:create) { raise Stripe::StripeError.new("Failed") }
          expect(Sentry).to receive(:capture_exception).with(kind_of(Stripe::StripeError), extra: { order_id: Order.first.id })

          click_on("Pay now")

          expect(StripePrice.count).to eql(1) # Price *did* get created
          expect(Order.count).to eql(1)
          expect(Order.first.state).to eql("new")
          expect(page).to have_text("Sorry, there was a problem trying to talk to the payment provider")
        end

        it "with other exceptions" do
          expect(Stripe::Product).to receive(:create) { raise "An error" }
          expect(Sentry).to receive(:capture_exception).with(kind_of(RuntimeError), extra: { order_id: Order.first.id })

          click_on("Pay now")

          expect(StripePrice.count).to eql(0)
          expect(Order.count).to eql(1)
          expect(Order.first.state).to eql("new")
          expect(page).to have_text("Sorry, there was an unexpected problem trying to update that order")
        end
      end # 'context "handle failures"'
    end # 'context "paid events" do'
  end # 'context "public sales" do'











  xcontext "reserver payments" do
    it "lets reservers pay" do
    end
  end # 'context "reserver payments" do'

  # Possibly put this into a different test, since it's a different controller
  # (but some of that's already tested above and it's all generally "orders").
  #
  xcontext "order management" do
    it "lets end users manage orders" do
    end

    # And it lets admins manage - perhaps don't do this here?
  end # 'context "order management" do'

  xcontext "other failure cases" do
    it "order pay state change attempt is invalid" do
    end
  end

  xcontext 'lots of model stuff' do
    it "order state machine" do
    end

    it "event state machine" do
    end

    it "event on-archive" do
    end
  end
end
