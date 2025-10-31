# =============================================================================
# A PLACEHOLDER ONLY
# =============================================================================
#
# Right now there's not really much need for webhook support. Testing is hard
# when you're running on localhost, and configuration is needed via the Stripe
# UI or some kind of one-time webhook creation over API would be required.
#
# It's all doable, but for small volume sites saying "start refunds on your
# web site's side, not Stripe's side" is easiest.
#
class Webhooks::StripeController < ApplicationController
  skip_before_action :verify_authenticity_token

  def webhook
    payload         = request.body.read
    sig_header      = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    event = begin
      if endpoint_secret.present?
        Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      else
        Stripe::Event.construct_from(
          JSON.parse(payload, symbolize_names: true)
        )
      end
    rescue JSON::ParserError => e
      head :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      head :unauthorized
      return
    end

    case event.type
      when 'payment_intent.succeeded'
        payment_intent = event.data.object # contains a Stripe::PaymentIntent
        puts 'PaymentIntent was successful!'
      when 'payment_method.attached'
        payment_method = event.data.object # contains a Stripe::PaymentMethod
        puts 'PaymentMethod was attached to a Customer!'
      # ... handle other event types
      else
        puts "Unhandled event type: #{event.type}"
    end
  end
end
