# Stripe's checkout system requires prices of items to be declared in advance.
# Each 'price' is given an ID, which this model records.
#
# Lazy-created when a customer goes to pay for an event booking, but no Stripe
# price has been created yet; an API call sets up the price in Stripe, then its
# ID is recorded herein for subsequent purchases.
#
# Stripe prices and related products are managed thereafter by the Event model,
# since it's well placed to know about deletion, cancellation and so-on.
#
class StripePrice < ApplicationRecord
  belongs_to :event
  validates_presence_of :event, :stripe_price_id
end
