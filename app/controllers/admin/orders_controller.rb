class Admin::OrdersController < ApplicationController

  layout 'admin'

  before_action :authenticate_admin_user! # (via Devise)
  before_action :get_page_and_event
  before_action :get_order, except: [:index]

  PERMITTED_ORDER_PARAMS = %i{
    name
    email
    phone_number
    number_of_seats
    amount_owed
    notes
  }

  public

    # GET /admin/pages/<page_id>/events/<event_id>/orders
    def index
      @orders = @event.orders.includes(:event)
    end

    # GET /admin/pages/<page_id>/events/<event_id>/orders/<id>
    def show
    end

    # GET /admin/pages/<page_id>/events/<event_id>/orders/new
    def new
      @order = Order.new(event: @event)
    end

    # POST /admin/pages/<page_id>/events/<event_id>/orders
    def create
      @order = Order.new(event: @event)
      safe_params = self.order_params()

      safe_params[:number_of_seats] = safe_params[:number_of_seats].to_i
      if safe_params[:number_of_seats] <= 0
        safe_params[:number_of_seats] = 0
      end

      if @event.currency.present?
        if safe_params[:amount_owed].present?
          parsed_amount = Monetize.parse(
            safe_params[:amount_owed],
            @event.currency
          )
          safe_params[:amount_owed] = parsed_amount.cents
        else
          safe_params[:amount_owed] = @event.price_per_seat * safe_params[:number_of_seats]
        end
      end

      @order.assign_attributes(safe_params)

      if @order.save
        if @order.amount_owed.zero?
          @order.pay_state!
        elsif @event.state_presales?
          @order.reserved_state!
        end

        redirect_to(
          admin_page_event_order_path(
            page_id:  @order.event.page.slug,
            event_id: @order.event.slug,
            id:       @order.id,
          ),
          notice: 'Order added successfully.'
        )
      else
        render :new
      end
    end

    # GET /admin/pages/<page_id>/events/<event_id>/orders/edit/<id>
    def edit
    end

    # PATCH/PUT /admin/pages/<page_id>/events/<event_id>/orders/<id>
    def update
      if params[:process] != 'state'
        return bail_out_with('Unrecognised order change requested') # NOTE EARLY EXIT
      end

      all_events   = Order.aasm(:state).events.map(&:name).map(&:to_s)
      valid_events = @order.valid_events.map(&:name).map(&:to_s)
      event_name   = params[:event]

      if all_events.exclude?(event_name)
        return bail_out_with('Unrecognised order change requested')
      elsif valid_events.exclude?(event_name)
        return bail_out_with('That order cannot be changed in that way')
      else
        ActiveRecord::Base.transaction do
          @order.send("#{event_name}_state!")
          notification = 'Order updated'

          if event_name == 'refund'
            notification = 'Order marked as refunded locally only. No matter how it was paid for - e.g. bank transfer or a processor such as Stripe - please make sure that this mechansim has been, or is used to actually return the paid money.'

            if @order.stripe_payment.present?
              stripe_refund = Stripe::Refund.create(payment_intent: @order.stripe_payment.stripe_payment_intent)

              if stripe_refund.status == 'succeeded'
                @order.stripe_payment.destroy!
                notification = 'Refund successfully processed automatically via Stripe.'
              end
            end
          end

          redirect_to(
            admin_page_event_orders_path(page_id: @page.slug, id: @event.slug),
            notice: notification
          )
        end
      end
    end

    # DELETE /admin/pages/<page_id>/events/<event_id>/orders/<id>
    #
    # See notes on the public OrdersController#destroy about this; the admin UI
    # usually doesn't delete orders, just maybe cancels them. But if the admin
    # really wants to delete something, well - they can.
    #
    def destroy
      flash_hash = if @order.state_paid?
        redirect_to(
          admin_page_event_order_path(page_id: @page.slug, event_id: @event.slug, id: @order.id),
          alert: 'You cannot delete a paid-for order; process a refund instead.'
        )
      else
        @order.destroy!

        redirect_to(
          admin_page_event_orders_path(page_id: @page.slug, id: @event.slug),
          notice: 'Order deleted. Customer web links to this order will no longer work.'
        )
      end
    end

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
      @order = Order.find_by_id(params[:id])
    end

    # Redirect to the order 'show' page with a given alert message if @order
    # is set, else the index page with that message.
    #
    def bail_out_with(alert_message)
      path = if @order.nil?
        admin_page_event_orders_path(page_id: @page.slug, event_id: @event.slug)
      else
        admin_page_event_order_path(
          page_id:  @order.event.page.slug,
          event_id: @order.event.slug,
          id:       @order.id
        )
      end

      return redirect_to(path, alert: alert_message)
    end

    def order_params
      return params.require(:order).permit(PERMITTED_ORDER_PARAMS)
    end

end
