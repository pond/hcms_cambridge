# Sets @page and @event via params' page_id' and 'event_id', which can specify
# either ID or slug. If the event and page are missing, redirects to root path
# with an appropriate warning; if only the event is missing, redirects to the
# page path with the same warning.
#
# Implemented via a before-action without any action exclusions.
#
module GetPageAndEventConcern
  extend ActiveSupport::Concern

  included do
    before_action :get_page_and_event
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
        path = @page.nil? ? root_path() : page_path(id: @page.slug)
        redirect_to path, alert: 'Sorry, that event seems to have disappeared!'
        return
      end
    end

end
