class EncountersController < ApplicationController

  layout 'encounters'

  def show
    if user_signed_in?
      redirect_to admin_encounter_path(id: params[:id])
    else
      @encounter  = Encounter.find_by_id_or_slug!(params[:id])
      @form_model = @encounter.form_class.new(pagelike: @encounter)
    end
  end
end
