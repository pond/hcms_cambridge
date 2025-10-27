class OrdersSelfServiceController < ApplicationController
  layout 'events'

  before_action :get_order_event_and_page

  def edit
  end

  def update
    event = params[:event] if params[:process] == 'state'

    case event
      when 'cancel'
        @order.cancel_state!
        redirect_to(
          page_event_path(page_id: @page.slug, id: @event.slug),
          notice: "OK, that's cancelled."
        )

      when 'pay'
        #
        # Order reserves a seat, event is accepting payments for reservations.
        #
        if @order.can_pay_for_reservation?
          redirect_to(
            edit_page_event_order_path(
              page_id:  @order.event.page.slug,
              event_id: @order.event.slug,
              id:       @order.id
            )
          )

        # Should only be possible for orders which had reserved a seat, but
        # then the event event went public and the order states were reset to
        # "new". Normally, orders in a "new" state for events accepting public
        # purchases go straight through to payment.
        #
        elsif @order.can_pay_for_booking?
          redirect_to(
            edit_page_event_order_path(
              page_id:  @order.event.page.slug,
              event_id: @order.event.slug,
              id:       @order.id
            )
          )

        # Shouldn't be here!
        #
        else
          Sentry.capture_message(
            "Tried to pay but states indicate this is not possible - order ID #{@order.id}",
            level: :error,
            extra: {
              controller: controller_name,
              action: action_name,
            },
            tags: {
              page: "#{controller_name}##{action_name}",
              path: request.path
            }
          )

          redirect_to(
            page_event_path(page_id: @page.slug, id: @event.slug),
            notice: "Sorry, this event isn't accepting payments anymore."
          )
        end

      else
        raise "Unsupported parameters - #{params[:event].inspect} / #{params[:process].inspect}"
    end
  rescue => e
    Sentry.capture_exception(e)

    redirect_to(
      page_event_path(page_id: @page.slug, id: @event.slug),
      notice: 'Sorry, there was an unexpected problem trying to update that order! Please try again later.'
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
