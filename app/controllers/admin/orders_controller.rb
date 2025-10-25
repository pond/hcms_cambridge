class Admin::OrdersController < ApplicationController

  layout 'admin'

  before_action :authenticate_admin_user! # (via Devise)
  before_action :get_page_and_event
  before_action :get_order, except: [:index]

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
      order_events = @order.valid_events.map(&:name).map(&:to_s)
      event_name   = params[:event]

      if all_events.exclude?(event_name)
        return bail_out_with('Unrecognised order change requested')
      elsif order_events.exclude?(event_name)
        return bail_out_with('That order cannot be changed in that way')
      else
        @order.send("#{event_name}_state!")
      end
    end

    # DELETE /admin/pages/<page_id>/events/<event_id>/orders/<id>
    #
    # See notes on the public OrdersController#destroy about this; the admin UI
    # usually doesn't delete orders, just maybe cancels them. But if the admin
    # really wants to delete something, well - they can.
    #
    def destroy
      @order.destroy!

      redirect_to(
        page_event_path(page_id: @page.slug, id: @event.slug),
        notice: "Order deleted - if the customer has any web links to this order, they will no longer work"
      )
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
end
