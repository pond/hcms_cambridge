class OrdersController < ApplicationController

  layout 'events'

  include GetPageAndEventConcern   # Sets @page and @event
  include GetOrderCarefullyConcern # Sets @order

  after_action :delete_stale_orders

  # Note ORDERS ARE NEVER EDITED in the public UI - they're created and, if
  # abandoned while in a "new" state may be destroyed, but after that it's all
  # done via state changes typically through OrdersSelfServiceController.
  #
  # The one special exception is "Amend order" in the reservation flow, for
  # new state orders only, where the in-progress order ID is given in a special
  # parameter.
  #
  def new
    if params[:with_order]
      order = Order.find_by_id(params[:with_order])
      @order = order if order&.state_new?
    end

    @order ||= Order.new(event: @event)
  end

  # This is one way that payment gateway (e.g. Stripe) checkout flow kicks
  # off, if relevant.
  #
  # The checkout flow is handled via redirection to OrdersSelfServiceController
  # and that's the other way payment can kick off - customer uses magic link,
  # which goes to that same controller.
  #
  def create
    @order = Order.new(event: @event)
    @order.assign_attributes(order_params())

    success = begin
      verify_recaptcha(action: 'order')
    rescue
      false
    end

    unless success
      flash[:alert] = "Sorry! The anti-robots checker wasn't happy... Please try again or contact us by phone or social medial for assistance."

      render :new
      return
    end

    # A user going Back and resubmitting the form (rather than using an "amend
    # details" in-page form button) might be causing lots of orders to pile up
    # quickly, potentially consuming seats. So long as the name and e-mail are
    # the same, we can be confident that the other order is now irrelevant and
    # delete it.
    #
    same_person_stale_order = Order.where.not(id: @order.id).where(
      event: @order.event,
      email: @order.email,
      name:  @order.name,
      state: Order.states[:new]
    ).first()

    same_person_stale_order.destroy! if same_person_stale_order.present?

    @order.amount_owed = (@order.number_of_seats || 0) * (@event.price_per_seat)

    if ! @order.save # Invalid record
      render(action_name == 'create' ? :new : :edit)
      return # NOTE EARLY EXIT
    end

    # Presales - just render the page that lets the user confirm the
    # reservation. It's the reservations equivalent of a checkout page.
    #
    if @event.state_presales?
      render :create_for_confirm_reservation

    # Full booking, but nothing owed; move to paid state immediately and
    # confirm the successful booking.
    #
    elsif @order.amount_owed.zero?
      @order.paid_state!
      redirect_to(
        page_event_path(page_id: @page.slug, id: @event.slug),
        notice: 'Thanks, your booing is confirmed! We look forward to seeing you there.'
      )

    # Payment flow. The user wants to pay now.
    #
    elsif @order.may_pay_state?
      render :create_for_confirm_booking

    # This flow is hit for orders created or edited (via self-service). The
    # rendering for reservations above happens, or we have valid order
    # details and now go on to sort payment. If we hit this 'else', then
    # state is strange - the order is for a booking and has an owed amount,
    # but it's not allowed to transition to a "paid" state. Perhaps the
    # event was updated "under our feet". Either way, give a hand-wavey
    # alert message and re-render the form.
    #
    else
      flash[:alert] = 'There was a problem with the order confirmation; please check the order details'
      render :new
    end
  rescue Stripe::StripeError => e
    Sentry.capture_exception(e, extra: { order_id: @order&.id })
    flash[:alert] = 'There was a problem trying to talk to the payment provider; please wait a moment, then try again. If problems persist, please get in touch!'
    render :new
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
    if @order.state_new?
      @order.destroy!

      redirect_to(
        page_event_path(page_id: @page.slug, id: @event.slug),
        notice: "OK, that's cancelled."
      )
    else
      redirect_to(
        root_path(),
        alert: 'Order management request could not be completed.'
      )
    end
  end

  # A non-RESTful POST endpoint, nested by page and event ID or slug.
  #
  def confirm_reservation
    ActiveRecord::Base.transaction do
      locked_order = Order.lock.find(@order.id)

      if locked_order.valid?
        locked_order.reserve_state!

        notice = 'Thanks, your reservation has been made! '

        # There's a chance of coming in through here via some not-yet-written
        # path for a public-facing order that's on a paid event, but free of
        # charge - e.g. any kind of future voucher code or similar thing. Deal
        # with that now, rather than leaving a potential future bug.
        #
        if locked_order.event.free_of_charge? || locked_order.amount_owed.zero?
          notice << 'We look forward to seeing you there.'
        else
          notice << "We'll be in touch when it's time to pay."
        end

        redirect_to(
          page_event_path(page_id: @page.slug, id: @event.slug),
          notice: notice
        )
      else # This should really only ever be for out-of-seats
        flash[:alert] = 'Sorry, it looks like there was a problem with the order - please check the details below'
        @order.validate() # (so that errors show up in the 'edit' form)
        render :edit
      end
    end
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called after-action. Sweeps away stale order records (those in a "new"
    # state which haven't been updated in a long time, including by whatever
    # action this controller just performed).
    #
    def delete_stale_orders
      Order.stale.delete_all # (delete -> direct SQL for speed; no callbacks)
    end

    def order_params
      permitted_order_params = %i{
        name
        email
        phone_number
        number_of_seats
      }

      unless Hcms.config.hide_order_notes
        permitted_order_params << :notes
      end

      return params.require(:order).permit(permitted_order_params)
    end

end
