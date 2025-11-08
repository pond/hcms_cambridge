require "spec_helper.rb"

RSpec.describe "Orders" do
  include OrdersHelper

  before :each do
    allow_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return('')

    allow(Hcms.config).to receive(:orders_email).and_return("orders@example.com")
    allow(Hcms.config).to receive(:site_name   ).and_return("Site Under Test")

    @page = create(:page, :events)
    @page.revisions.first.update!(published: true)

    @event = create(:event, page: @page)
    @event.revisions.first.update!(published: true)
  end

  context "presales" do
    it "validates the form" do
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
      expect(Order.first.state).to eql("new")

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
      expect(page).to have_text("Thanks, your reservation has been made!")

      messages = spechelp_decode_multipart(count: 2)

      to_customer = spechelper_find_in_decoded(messages, to: email)
      to_admin    = spechelper_find_in_decoded(messages, to: 'orders@example.com')

      expect(to_customer.email.from   ).to eql(["orders@example.com"])
      expect(to_customer.email.subject).to eql("Reservation confirmed for \"#{@event.title}\"")

      expect(to_customer.text).to include(@event.title.upcase)
      expect(to_customer.text).to include(total)
      expect(to_customer.text).to include(ordershelp_magic_link(Order.first))

      expect(to_customer.html).to include(@event.title)
      expect(to_customer.html).to include(total)
      expect(to_customer.html).to have_link('Manage order', href: ordershelp_magic_link(Order.first))

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

    it "lets the user cancel" do
    end
  end

  context "public sales" do
  end
end
