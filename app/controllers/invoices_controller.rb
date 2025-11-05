class InvoicesController < OrdersController
  layout 'invoices'

  include GetPageAndEventConcern   # Sets @page and @event
  include GetOrderCarefullyConcern # Sets @order

  def show
    render()
  end
end
