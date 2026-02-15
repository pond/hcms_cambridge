class EventsController < ApplicationController

  layout 'events'

  def show
    if user_signed_in?
      redirect_to admin_page_event_path(page_id: params[:page_id], id: params[:id])
    else
      @page  =  Page.find_by_id_or_slug!( params[ :page_id ] )
      @event = Event.find_by_id_or_slug!( params[ :id      ] )
    end
  end
end
