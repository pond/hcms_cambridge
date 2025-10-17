class OrdersController < ApplicationController

  layout 'events'

  def new
    @page    = Page.find_by_id(params[:page_id])
    @page  ||= Page.find_by_slug(params[:page_id])
    @event   = @page&.events&.find_by_id(params[:event_id])
    @event ||= @page&.events&.find_by_slug(params[:event_id])

    if @event.nil?
      path = @page.nil? ? root_path() : page_path(@page.id)
      redirect_to path, notice: "Sorry, that event seems to have disappeared!"
      return
    end

    @order = Order.new(event: @event)
  end
end
