class EncounterInvoicesController < ApplicationController

  layout 'invoices'

  def show

    # Tidy up URLs from "use a GET-based form to get standard button styling"
    # hacks. We wouldn't care so much except printed output tends to include
    # the page URL.
    #
    raw_uri = request.env['REQUEST_URI']

    if raw_uri&.end_with?('?')
      redirect_to(raw_uri.chomp('?'), status: :moved_permanently)
    else
      @encounter       = Encounter.find_by_id_or_slug!(params[:encounter_id])
      @encounter_order = @encounter.encounter_orders.find(params[:encounter_order_id])

      render()
    end
  end
end
