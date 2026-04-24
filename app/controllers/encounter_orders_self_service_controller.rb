# Handles 'magic links' in e-mails, used by customers to provide any extra
# information needed for an encounter order that an administrator created,
# then pay.
#
class EncounterOrdersSelfServiceController < ApplicationController

  layout 'encounters'

  before_action :get_encounter_order_and_encounter

  def edit
    render()
  end

  def update
    event = if params[:state_pay]
      'pay'
    elsif params[:state_cancel]
      'cancel'
    else
      'invalid'
    end

    # Params for a given state should only happen if the state is valid, but we
    # do have to account for race conditions if things change "under our feet",
    # stale pages, hacking attempts and so-on.

    # User has elected to cancel their order 🥺
    #
    if event == 'cancel'
      @encounter_order.cancel_state!

      redirect_to(
        root_path(),
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
      unless @encounter_order.customer_can_pay_for_booking?
        Sentry.capture_message(
          "Tried to pay but states indicate this is not possible - encounter order ID #{@encounter_order.id}",
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
          helpers.encordshelp_magic_link(@encounter_order),
          notice: "Sorry, this encounter isn't accepting payments anymore."
        )

        return # NOTE EARLY EXIT
      end

      # Account for any additional form data that might be specified (dealing
      # manually with the known, expected customer-settable fields) and handle
      # validation.
      #
      if params[:encounter_order].present?
        safe_params = if @encounter_order.user_chooses_has_physical
          params.require(:encounter_order).permit(:gift_note, :has_physical, :address)
        else
          params.require(:encounter_order).permit(:gift_note, :address)
        end

        @encounter_order.assign_attributes(safe_params)

        unless @encounter_order.valid?
          flash.now[:alert] = "Oops, it looks like some information isn't quite right! Please check the highlighted fields below."
          render :edit
          return
        end

        if @encounter_order.user_chooses_has_physical && @encounter_order.has_physical_changed?
          if @encounter_order.has_physical
            @encounter_order.amount_owed += @encounter.price_physical
          else
            @encounter_order.amount_owed -= @encounter.price_physical
          end
        end

        @encounter_order.save!
      end

      # Edge case - "paying" for a free item. Just say, "confirmed".
      #
      if @encounter_order.amount_owed.zero?
        @encounter_order.pay_state!

        redirect_to(
          helpers.encordshelp_magic_link(@encounter_order),
          notice: 'Thanks, your encounter booking is confirmed! We look forward to seeing you there.'
        )

        return # NOTE EARLY EXIT
      end

      product_url  = encounter_url(@encounter)
      stripe_price = @encounter.get_or_create_stripe_price(with_encounter_url: product_url)

      branding_settings = {
        background_color: (Hcms.config.stripe[:checkout_background] rescue '#ffffff'),
        display_name:     Hcms.config.site_name,
        logo:  {
          type: 'url',
          url:  helpers.image_url('logo.svg'),
        }
      }

      invoice_data = {
        description: @encounter.title,
        footer:      [Hcms.config.site_name, Hcms.config.orders_email].reject(&:blank?).join(' / '),
      }

      base_success_url      = stripe_encounter_order_payment_succeeded_url(encounter_order_id: @encounter_order.id, token: @encounter_order.token)
      base_cancel_url       = stripe_encounter_order_payment_cancelled_url(encounter_order_id: @encounter_order.id, token: @encounter_order.token)
      templated_success_url = base_success_url + '?csid={CHECKOUT_SESSION_ID}'
      templated_cancel_url  = base_cancel_url  + '?csid={CHECKOUT_SESSION_ID}'

      if @encounter_order.price_agreed_by_application?
        line_items = [{
          quantity:   1,
          price_data: {
            currency:     @encounter.currency,
            unit_amount:  @encounter_order.amount_owed,
            product_data: {
              name:        @encounter.title,
              description: "Date & time: #{helpers.encordshelp_datetime(@encounter_order)}",
              images:      [@encounter.product_image_url],
            }
          }
        }]

        tax = @encounter_order.amount_of_tax_owed

        if tax > 0
          line_items += [{
            quantity:   1,
            price_data: {
              currency:     @encounter.currency,
              unit_amount:  tax,
              product_data: {
                name: Hcms.config.tax_name.presence || "Sales tax"
              }
            }
          }]
        end
      elsif @encounter_order.includes_discount?
        line_items = [{
          quantity:   1,
          price_data: {
            currency:     @encounter.currency,
            unit_amount:  @encounter_order.amount_owed,
            product_data: {
              name:        @encounter.title,
              description: "Date & time: #{helpers.encordshelp_datetime(@encounter_order)}",
              images:      [@encounter.product_image_url],
            }
          }
        }]
      elsif @encounter_order.has_physical && @encounter.price_physical.present?
        line_items = [
          {
            quantity: @encounter_order.number_of_seats,
            price:    stripe_price.stripe_price_id,
          },
          {
            quantity:   1,
            price_data: {
              currency:     @encounter.currency,
              unit_amount:  @encounter.price_physical,
              product_data: {
                name:        @encounter.name_physical.upcase_first,
                unit_label:  "item",
              }
            }
          }
        ]
      else
        line_items = [{
          quantity: @encounter_order.number_of_seats,
          price:    stripe_price.stripe_price_id,
        }]
      end

      session = Stripe::Checkout::Session.create(
        mode:              'payment',
        success_url:       templated_success_url,
        cancel_url:        templated_cancel_url,
        customer_email:    @encounter_order.email,
        branding_settings: branding_settings,
        line_items:        line_items,
        invoice_creation:  {
          enabled:      true,
          invoice_data: invoice_data,
        },
      )

      redirect_to(session.url, status: :see_other, allow_other_host: true) # (HTTP 303)
    else
      raise "Unsupported parameters - #{params.inspect}"
    end

  rescue Stripe::StripeError => e
    Sentry.capture_exception(e, extra: { encounter_order_id: @encounter_order&.id })

    flash[:alert] = 'Sorry, there was a problem trying to talk to the payment provider. Please wait a moment, then try again. If problems persist, please get in touch!'
    render :edit

  rescue StandardError => e
    Sentry.capture_exception(e, extra: { encounter_order_id: (@encounter_order&.id rescue nil) })

    redirect_to(
      helpers.encordshelp_magic_link(@encounter_order),
      alert: 'Sorry, there was an unexpected problem trying to process the booking. Please try again later.'
    )
  end

  # DELETE /encounters/<encounter_id>/encounter_orders/<encounter_order_id>
  #
  # When the end user cancels an order that's in flight, it just gets deleted
  # since there's no point keeping unfinished order records around the place.
  # In the admin UI, cancellation changes the order object state to "cancelled"
  # instead, because the end user might have a link to that order item and it
  # would be surprising if the link just broke.
  #
  def destroy
    @encounter_order.destroy!

    redirect_to(
      root_path(),
      notice: "OK, that's cancelled."
    )
  end

  # A non-RESTful GET endpoint, nested by encounter ID or slug, and encounter
  # order ID. Stripe redirects here when payment succeeds including the session
  # ID via a template variable in the URL we gave them. See the payment flow in
  # #update for more.
  #
  def stripe_payment_succeeded
    ActiveRecord::Base.transaction do
      begin
        locked_order = EncounterOrder.lock.find(@encounter_order.id)
        locked_order.pay_state!
      rescue StandardError => e
        Sentry.capture_message(
          "URGENT: Payment made but website-side encounter order update failed (#{@encounter_order&.id} / #{@encounter_order&.email} / #{@encounter_order&.name})",
          level: :error,
          extra: {
            controller:            controller_name,
            action:                action_name,
            encounter_order_id:    @encounter_order&.id,
            encounter_order_name:  @encounter_order&.name,
            encounter_order_email: @encounter_order&.email,
          },
          tags: {
            page: "#{controller_name}\##{action_name}",
            path: request.path
          }
        )

        Admin::AdminMailer.problematic_encounter_order_email(@encounter_order).deliver_now()
        Sentry.capture_exception(e, extra: { encounter_order_id: (@encounter_order&.id rescue nil) })

        return # NOTE EARLY EXIT (but note the 'ensure' clause below)
      end

      # Try to get the payment details for our-side refund, but this isn't
      # critical so we do it outside the above transaction and lock.
      #
      begin
        session = Stripe::Checkout::Session.retrieve(params[:csid])
        StripePayment.create!(
          payable:               @encounter_order,
          stripe_payment_intent: session.payment_intent
        )
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { encounter_order_id: @encounter_order&.id })
      end
    end

  ensure
    #
    # Success or not, *do not panic the user!* - there is nothing they can do.
    # We have to hope our monitoring and alerting worked OK so that if there
    # was a problem, it can be manually resolved.
    #
    redirect_to(
      helpers.encordshelp_magic_link(@encounter_order),
      notice: 'Thanks, your encounter booking is confirmed! We look forward to seeing you there.'
    )
  end

  # As above, but for Stripe-side cancellations.
  #
  def stripe_payment_cancelled
    redirect_to(
      helpers.encordshelp_magic_link(@encounter_order),
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
    def get_encounter_order_and_encounter
      @encounter_order = EncounterOrder.find_by_id(params[:encounter_order_id])
      sleep(rand() / 2) unless Rails.env.test? # Endpoint isn't high security, but thwart timing attacks anyway

      if @encounter_order.nil? || @encounter_order.token != params[:token] || @encounter_order.token_expires_at < Time.current
        redirect_to root_path(), alert: 'Sorry, that encounter link does not seem to be valid - it might have expired.'
        return # NOTE EARLY EXIT
      end

      @encounter = @encounter_order.encounter
    end

end
