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
    end

    # DELETE /admin/pages/<page_id>/events/<event_id>/orders/<id>
    def destroy
      #@order.destroy!
      #...
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
end
