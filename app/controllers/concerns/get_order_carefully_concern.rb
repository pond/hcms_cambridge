# Only include after GetPageAndEventConcern.
#
# Sets 'order via the UUID in param 'id' or 'order_id' (in that order). If
# a corresponding Order record cannot be found, or if the event does not match
# @event (see GetPageAndEventConcern), acts as if the order is missing and
# redirects to the event page with a warning.
#
# Implemented via a before-action *except* on 'new' or 'create' actions.
#
module GetOrderCarefullyConcern
  extend ActiveSupport::Concern

  included do
    before_action :get_order, except: [:new, :create]
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called before-action.
    #
    def get_order
      order = Order.find_by_id(params[:id] || params[:order_id])

      if order&.event_id == @event.id
        @order = order
      else
        redirect_to(
          page_event_path(page_id: @event.page.slug, id: @event.slug),
          alert: 'Sorry, that reservation or booking cannot be found!'
        )
      end
    end

end
