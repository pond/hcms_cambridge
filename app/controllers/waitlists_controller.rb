class WaitlistsController < ApplicationController

  layout 'events'

  before_action :get_page_and_event

  PERMITTED_PARAMS = %i{
    name
    email
    phone_number
    number_of_seats
  }

  def show
    render()
  end

  def new
    @order = Order.new(event: @event)
  end

  # For the form, we lean on the Order model to accept basics in an easy to
  # handle way that can share a lot of other code elsewhere; when the form is
  # submitted, the order object is likely invalid - but we only care about
  # validation errors on attributes relevant to our subset form.
  #
  def create
    @order      = Order.new(event: @event)
    safe_params = params.require(:order).permit(PERMITTED_PARAMS)

    @order.assign_attributes(safe_params)

    success = begin
      verify_recaptcha(action: 'waitlist')
    rescue
      false
    end

    unless success
      flash[:alert] = "Sorry! The anti-robots checker wasn't happy... Please try again or contact us by phone or social medial for assistance."

      render :new
      return
    end

    @order.validate()
    @order.errors.delete(:number_of_seats)

    relevant_validation_errors = PERMITTED_PARAMS.any? { | attr | @order.errors.has_key?(attr) }

    if relevant_validation_errors
      render :new
    else
      WaitlistMailer.join_waitlist_request_email(@order).deliver()

      redirect_to(
        event_waitlist_path(event_id: @event.slug),
        notice: "Thanks - you're on the waitlist."
      )
    end
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private


    # Called before-action; gets the event from param 'event_id' via ID or
    # slug and stores it in @event; sets @page from this event's stored page.
    #
    def get_page_and_event
      @event = Event.find_by_id_or_slug!(params[:event_id])
      @page   = @event.page
    end

end
