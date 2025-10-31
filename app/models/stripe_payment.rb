# Stripe is managed via the offsite ("hosted") checkout flow. We pass a success
# URL that includes Stripe's checkout session ID, so when the browser is
# directed to that URL, we can get and store the charge ID over API using that
# session information. A payment record is then written with the charge ID,
# which allows an over-API refund later.
#
# A refund actioned on our side and completed by Stripe will result in the
# corresponding payment record being deleted. If a refund is done fully in
# Stripe, we don't know about it and the payment record won't be cleaned up.
#
class StripePayment < ApplicationRecord
  belongs_to :order
  validates_presence_of :order, :stripe_payment_intent
end
