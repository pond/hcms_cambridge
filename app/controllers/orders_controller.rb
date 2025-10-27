class OrdersController < ApplicationController

  layout 'events'

  before_action :get_page_and_event
  before_action :get_order, except: [:new, :create]

  after_action :delete_stale_orders

  def new
    @order = Order.new(event: @event)
  end

  def create
    @order = Order.new(event: @event)
    handle_form_submission()
  end

  def edit
    render()
  end

  def update
    handle_form_submission()
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
      notice: "OK, that's cancelled - no seats will be held for this event"
    )
  end

  # A non-RESTful POST endpoint, nested by page and event ID or slug.
  #
  def confirm_reservation
    ActiveRecord::Base.transaction do
      locked_order = Order.lock.find(@order.id)

      if locked_order.valid?
        locked_order.reserve_state!

        notice = 'Thanks, your reservation has been made! '

        if locked_order.event.free_of_charge?
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

  # A non-RESTful POST endpoint, nested by page and event ID or slug.
  #
  # The Stripe checkout flow kicks off here.
  #
  def checkout
    # Show total price, say "are you sure", or embed Stripe iframe?
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called before-action.
    #
    def get_page_and_event
      @page    = Page.find_by_slug(params[:page_id])
      @page  ||= Page.find_by_id(params[:page_id])
      @event   = @page&.events&.find_by_slug(params[:event_id])
      @event ||= @page&.events&.find_by_id(params[:event_id])

      if @event.nil?
        path = @page.nil? ? root_path() : page_path(@page.id)
        redirect_to path, notice: 'Sorry, that event seems to have disappeared!'
        return
      end
    end

    # Called before-action.
    #
    def get_order
      order = Order.find_by_id(params[:id])

      if order&.event_id == @event.id
        @order = order
      else
        redirect_to(
          page_event_path(page_id: @event.page.slug, id: @event.slug),
          alert: 'Sorry, that reservation or booking cannot be found!'
        )
      end
    end

    # Called after-action. Sweeps away stale order records (those in a "new"
    # state which haven't been updated in a long time, including by whatever
    # action this controller just performed).
    #
    def delete_stale_orders
      Order.stale.delete_all # (delete -> direct SQL for speed; no callbacks)
    end

    # Used by #create and #update. Instantiate a new @order or load an existing
    #one, then call here.
    #
    def handle_form_submission
      @order.assign_attributes(order_params())

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

      if @order.valid?
        @order.save!

        if @event.state_presales?
          render :create_for_confirm_reservation
        else
          render :create_for_checkout
        end
      else
        render :new
      end
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
