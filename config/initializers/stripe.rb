if ENV['STRIPE_API_KEY'].present?
  require 'stripe'
  Stripe.api_key = ENV['STRIPE_API_KEY']
  Hcms.config.payments_enabled = true
else
  Hcms.config.payments_enabled = false
end
