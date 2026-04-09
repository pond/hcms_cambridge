require 'spec_helper'

# This is just a way to group / encapsulate some helper methods.
#
RSpec.shared_context "encounter orders" do
  include ApplicationHelper
  include EncounterOrdersHelper

  before :each do
    allow(Hcms.config).to receive(:orders_email).and_return("orders@example.com")
    allow(Hcms.config).to receive(:site_name   ).and_return("Site Under Test")
  end

  # Returns a mock payment intent for successful payment
  #
  def simulate_stripe_payment(encounter_order)
    encounter   = encounter_order.encounter
    mock_payint = nil

    if encounter_order.amount_owed.zero?
      click_on("Finalise booking")

      expect(page).to have_text("Thanks, your encounter booking is confirmed")
      expect(StripePayment.count).to eql(0)
    else
      mock_prodid  = "product_test_1234"
      mock_priceid = "price_test_1234"
      mock_csid    = "cs_test_1234"
      mock_payint  = "pi_test_1234"

      expect(Stripe::Product).to receive(:create).once do | args |
        expect(args[:name]).to eql(encounter.title)

        double(id: mock_prodid)
      end

      expect(Stripe::Price).to receive(:create).once do | args |
        expect(args[:currency   ]).to eql(encounter.currency)
        expect(args[:unit_amount]).to eql(encounter.price_per_seat)
        expect(args[:product    ]).to eql(mock_prodid)

        double(id: mock_priceid)
      end

      expect(Stripe::Checkout::Session).to receive(:create).once do | args |
        encounter_order.reload # Might have changed via "Pay now" form submission

        expect(args[:mode]).to eql("payment")
        expect(args[:success_url]).to include("manage_encounter")
        expect(args[:cancel_url ]).to include("manage_encounter")
        expect(args[:success_url]).to end_with("stripe_payment_succeeded?csid={CHECKOUT_SESSION_ID}")
        expect(args[:cancel_url ]).to end_with("stripe_payment_cancelled?csid={CHECKOUT_SESSION_ID}")

        if encounter_order.includes_discount?
          expect(args[:line_items].size ).to eql(1)
          expect(args[:line_items].first).to eql(
            {
              quantity: 1,
              price_data: {
                currency: encounter.currency,
                unit_amount: encounter_order.amount_owed,
                product_data: {
                  name:        encounter.title,
                  description: encordshelp_datetime(encounter_order),
                  images:      [encounter.product_image_url],
                  unit_label:  "booking",
                }
              }
            }
          )
        else
          items_count = encounter.has_physical_aspect? && encounter_order.has_physical == true ? 2 : 1

          expect(args[:line_items].size  ).to eql(items_count)
          expect(args[:line_items].first ).to eql({quantity: encounter_order.number_of_seats, price: mock_priceid})
          expect(args[:line_items].second).to eql(
            {
              quantity: 1,
              price_data: {
                currency: encounter.currency,
                unit_amount: encounter.price_physical,
                product_data: {
                  name: encounter.name_physical.upcase_first,
                  unit_label: "item"
                }
              }
            }
          ) if items_count == 2
        end

        double(url: args[:success_url].gsub("{CHECKOUT_SESSION_ID}", mock_csid))
      end

      expect(Stripe::Checkout::Session).to receive(:retrieve).with(mock_csid) do
        double(payment_intent: mock_payint)
      end

      click_on("Pay now")

      expect(page).to have_text("Thanks, your encounter booking is confirmed")
      expect(StripePrice.count).to eql(1)
      expect(StripePrice.first.stripe_price_id).to eql(mock_priceid)
      expect(StripePayment.count).to eql(1)
      expect(StripePayment.first.stripe_payment_intent).to eql(mock_payint)
    end

    encounter_order.reload

    expect(encounter_order.state).to eql("paid")
    verify_upon_payment_emails(encounter_order)

    ActionMailer::Base.deliveries.clear()

    return mock_payint
  end

  def verify_upon_payment_emails(encounter_order)
    encounter   = encounter_order.encounter
    messages    = spechelp_decode_multipart(count: 2)
    to_customer = spechelper_find_in_decoded(messages, to: encounter_order.email)
    to_admin    = spechelper_find_in_decoded(messages, to: "orders@example.com")
    total       = spechelp_format_money(encounter_order.amount_owed, encounter.currency)

    expect(to_customer).to be_present
    expect(to_admin   ).to be_present

    expect(to_customer.email.from   ).to eql(["orders@example.com"])
    expect(to_customer.email.subject).to eql("Booking confirmed for \"#{encounter.title}\"")

    expect(to_customer.text).to include(encounter.title.upcase)
    expect(to_customer.text).to include(encordshelp_share_link(encounter_order))
    expect(to_customer.text).to include(encordshelp_magic_link(encounter_order))

    expect(to_customer.html).to include(encounter.title)
    expect(to_customer.html).to have_link("Your encounter", href: encordshelp_share_link(encounter_order))
    expect(to_customer.html).to have_link("Manage booking", href: encordshelp_magic_link(encounter_order))

    if encounter_order.amount_owed.zero? # (don't want to see "$0.00" or similar)
      expect(to_customer.text).to_not include(total)
      expect(to_customer.html).to_not include(total)
    else
      expect(to_customer.text).to     include(total)
      expect(to_customer.html).to     include(total)
    end

    expect(to_admin.email.from   ).to eql(["orders@example.com"])
    expect(to_admin.email.subject).to eql("[Site Under Test] New encounter booking from #{encounter_order.name}")

    expect(to_admin.text).to include(encounter_order.name)
    expect(to_admin.text).to include(encounter_order.email)
    expect(to_admin.text).to include(encounter_order.phone_number)

    expect(to_admin.html).to have_css("dd", text: encounter_order.name)
    expect(to_admin.html).to have_css("dd", text: encounter_order.number_of_seats)
    spechelp_check_mailto(
      html:    to_admin.html,
      email:   encounter_order.email,
      subject: "Your booking for \"#{encounter.title}\""
    )
    spechelp_check_tel(
      html:  to_admin.html,
      phone: encounter_order.phone_number
    )
    expect(to_admin.html).to have_link(
      "Manage booking",
      href: admin_encounter_encounter_order_url(encounter_id: encounter.slug, id: encounter_order.id)
    )
    expect(to_admin.html).to have_link(
      "here", # ...as in, "You can find a list of all encounter bookings <here>"
      href: admin_encounter_encounter_orders_url(encounter_id: encounter.slug)
    )
  end

  def verify_upon_refund_email(encounter_order)
    encounter   = encounter_order.encounter
    to_customer = spechelp_decode_multipart()
    total       = spechelp_format_money(encounter_order.amount_owed, encounter.currency)

    expect(to_customer.email.to     ).to eql([encounter_order.email])
    expect(to_customer.email.from   ).to eql(["orders@example.com"])
    expect(to_customer.email.subject).to eql("Confirmation of refund for \"#{encounter.title}\"")

    expect(to_customer.text).to include(encounter.title.upcase)
    expect(to_customer.text).to include("Your payment of #{total} has been refunded")

    expect(to_customer.html).to include(encounter.title)
    expect(to_customer.html).to include("Your payment of #{total}")
    expect(to_customer.html).to include("has been refunded")
  end
end
