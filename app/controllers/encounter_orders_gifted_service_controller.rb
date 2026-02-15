# Handles 'magic links' in e-mails that are sent to gift recipients. Shows
# information about their ordered encounter without giving prices or other
# such details away.
#
class EncounterOrdersGiftedServiceController < ApplicationController

  layout 'encounters'

  def show
    @encounter_order = EncounterOrder.find_by_token(params[:token])

    if @encounter_order.nil? || @encounter_order.encounter.nil?
      redirect_to(root_path(), notice: "Sorry, there doesn't seem to be any encounter information available there.")
      return # NOTE EARLY EXIT
    end

    @encounter = @encounter_order.encounter
  end
end
