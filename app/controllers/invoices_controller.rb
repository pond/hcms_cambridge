class InvoicesController < ApplicationController

  layout 'invoices'

  include GetPageAndEventConcern   # Sets @page and @event
  include GetOrderCarefullyConcern # Sets @order

  def show

    # Tidy up URLs from "use a GET-based from to get standard button styling"
    # hacks. We wouldn't care so much except printed output tends to include
    # the page URL.
    #
    raw_uri = request.env['REQUEST_URI']

    if raw_uri&.end_with?('?')
      redirect_to(raw_uri.chomp('?'), status: :moved_permanently)
    else
      render()
    end
  end
end
