class InvoicesController < OrdersController

  layout 'invoices'

  include GetPageAndEventConcern   # Sets @page and @event
  include GetOrderCarefullyConcern # Sets @order

  def show

    # Tidy up URLs from "use a GET-based from to get standard button styling"
    # hacks. We wouldn't care so much except printed output tends to include
    # the page URL.
    #
    if request.url.end_with?('?')
      redirect_to(request.url.chomp('?'))
      return
    end

    render()
  end
end
