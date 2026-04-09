# Handles 'magic links' in e-mails but is also used for e.g. the checkout flow
# when a new order is valid, saved, and goes directly to payment.
#
class OrdersSelfServiceController < ApplicationController

  layout 'events'

  before_action :get_order_event_and_page

  def edit
    render()
  end

  def update
    event = params[:event] if params[:process] == 'state'

    # Params for a given state should only happen if the state is valid, but we
    # do have to account for race conditions if Events change "under our feet",
    # stale pages, hacking attempts and so-on.

    # User has elected to cancel their order 🥺
    #
    if event == 'cancel'
      @order.cancel_state!

      redirect_to(
        page_event_path(page_id: @page.slug, id: @event.slug),
        notice: "OK, that's cancelled."
      )

    # * Order reserves a seat, event is accepting payments for reservations.
    #
    # * Any path which leads to general payments being possible, including
    #   a reservation-purchase-only order with some unclaimed reservations
    #   going to public-sales and thus some order states resetting to 'new'.
    #
    # We intentionally redirect out to gateway-hosted payment pages, as we
    # consider those to be the more 'trusted brand' when it comes to things
    # like entering a credit card number, rather than e.g. embedding as an
    # iframe. We of course don't accept the card number directly, as that
    # incurs significant PCI compliance obligations.
    #
    elsif event == 'pay'

      # First deal with the unhappy path, then the payment flow.
      #
      unless @order.customer_can_pay_for_reservation? || @order.customer_can_pay_for_booking?
        Sentry.capture_message(
          "Tried to pay but states indicate this is not possible - order ID #{@order.id}",
          level: :error,
          extra: {
            controller: controller_name,
            action:     action_name,
          },
          tags: {
            page: "#{controller_name}\##{action_name}",
            path: request.path
          }
        )

        redirect_to(
          page_event_path(page_id: @page.slug, id: @event.slug),
          notice: "Sorry, this event isn't accepting payments anymore."
        )

        return # NOTE EARLY EXIT
      end

      # Edge case - "paying" for a free item. Just say, "booking confirmed".
      #
      if @order.amount_owed.zero?
        @order.pay_state!
        redirect_to(
          page_event_path(page_id: @page.slug, id: @event.slug),
          notice: 'Thanks, your booking is confirmed! We look forward to seeing you there.'
        )

        return # NOTE EARLY EXIT
      end

      event_url    = page_event_url(page_id: @event.page.slug, id: @event.slug)
      stripe_price = @event.get_or_create_stripe_price(with_event_url: event_url)

      branding_settings = {
        background_color: (Hcms.config.stripe[:checkout_background] rescue '#ffffff'),
        display_name:     Hcms.config.site_name,
        logo:  {
          type: 'url',
          url:  helpers.image_url('logo.svg'),
        }
      }

      invoice_data = {
        description: @event.title,
        footer:      [Hcms.config.site_name, Hcms.config.orders_email].reject(&:blank?).join(' / '),
      }

      base_success_url      = stripe_order_payment_succeeded_url(order_id: @order.id, token: @order.token)
      base_cancel_url       = stripe_order_payment_cancelled_url(order_id: @order.id, token: @order.token)
      templated_success_url = base_success_url + '?csid={CHECKOUT_SESSION_ID}'
      templated_cancel_url  = base_cancel_url  + '?csid={CHECKOUT_SESSION_ID}'

      if @order.includes_discount?
        line_items = [{
          quantity:   1,
          price_data: {
            currency:     @event.currency,
            unit_amount:  @order.amount_owed,
            product_data: {
              name:        @event.title,
              description: helpers.evtshelp_datetime(@event),
              images:      [@event.product_image_url],
              unit_label:  "booking",
            }
          }
        }]
      else
        line_items = [{
          quantity: @order.number_of_seats,
          price:    stripe_price.stripe_price_id,
        }]
      end

      session = Stripe::Checkout::Session.create(
        mode:              'payment',
        success_url:       templated_success_url,
        cancel_url:        templated_cancel_url,
        customer_email:    @order.email,
        branding_settings: branding_settings,
        line_items:        line_items,
        invoice_creation:  {
          enabled:      true,
          invoice_data: invoice_data,
        },
      )

      redirect_to(session.url, status: :see_other, allow_other_host: true) # (HTTP 303)
    else
      raise "Unsupported parameters - #{params[:event].inspect} / #{params[:process].inspect}"
    end

  rescue Stripe::StripeError => e
    Sentry.capture_exception(e, extra: { order_id: @order&.id })

    flash[:alert] = 'Sorry, there was a problem trying to talk to the payment provider. Please wait a moment, then try again. If problems persist, please get in touch!'
    render :edit

  rescue StandardError => e
    Sentry.capture_exception(e, extra: { order_id: (@order&.id rescue nil) })

    redirect_to(
      page_event_path(page_id: @page.slug, id: @event.slug),
      alert: 'Sorry, there was an unexpected problem trying to process that order. Please try again later.'
    )
  end

  # DELETE /pages/<page_id>/events/<event_id>/orders/<order_id>
  #
  # When the end user cancels an order that's in flight, it just gets deleted
  # since there's no point keeping unfinished order records around the place.
  # In the admin UI, cancellation changes the order object state to "cancelled"
  # instead, because the end user might have a link to that order item and it
  # would be surprising if the link just broke.
  #
  def destroy
    @order.destroy!

    redirect_to(
      page_event_path(page_id: @page.slug, id: @event.slug),
      notice: "OK, that's cancelled."
    )
  end

  # A non-RESTful GET endpoint, nested by page and event ID or slug, and order
  # ID. Stripe redirects here when payment succeeds including the session ID
  # via a template variable in the URL we gave them. See the payment flow in
  # #update for more.
  #
  def stripe_payment_succeeded
    ActiveRecord::Base.transaction do
      begin
        locked_order = Order.lock.find(@order.id)
        locked_order.pay_state!
      rescue StandardError => e
        Sentry.capture_message(
          "URGENT: Payment made but website-side order update failed (#{@order&.id} / #{@order&.email} / #{@order&.name})",
          level: :error,
          extra: {
            controller:  controller_name,
            action:      action_name,
            order_id:    @order&.id,
            order_name:  @order&.name,
            order_email: @order&.email,
          },
          tags: {
            page: "#{controller_name}\##{action_name}",
            path: request.path
          }
        )

        Admin::AdminMailer.problematic_order_email(@order).deliver_now()
        Sentry.capture_exception(e, extra: { order_id: (@order&.id rescue nil) })

        return # NOTE EARLY EXIT (but note the 'ensure' clause below)
      end

      # Try to get the payment details for our-side refund, but this isn't
      # critical so we do it outside the above transaction and lock.
      #
      begin
        session = Stripe::Checkout::Session.retrieve(params[:csid])
        StripePayment.create!(
          payable:               @order,
          stripe_payment_intent: session.payment_intent
        )
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { order_id: @order&.id })
      end
    end

  ensure
    #
    # Success or not, *do not panic the user!* - there is nothing they can do.
    # We have to hope our monitoring and alerting worked OK so that if there
    # was a problem, it can be manually resolved.
    #
    redirect_to(
      page_event_path(page_id: @page.slug, id: @event.slug),
      notice: 'Thanks, your booking is confirmed! We look forward to seeing you there.'
    )
  end

  # As above, but for Stripe-side cancellations.
  #
  def stripe_payment_cancelled
    redirect_to(
      manage_order_path(order_id: @order.id, token: @order.token),
      notice: "Please confirm cancellation by using the 'cancel' button below, or retry with the 'pay now' button."
    )
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called before-action.
    #
    def get_order_event_and_page
      @order = Order.find_by_id(params[:order_id])
      sleep(rand() / 2) unless Rails.env.test? # Endpoint isn't high security, but thwart timing attacks anyway

      if @order.nil? || @order.token != params[:token] || @order.token_expires_at < Time.current
        redirect_to root_path(), alert: 'Sorry, that order link does not seem to be valid - it might have expired.'
        return # NOTE EARLY EXIT
      end

      @event = @order.event
      @page  = @order.event.page
    end

end
