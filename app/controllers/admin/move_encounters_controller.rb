# This is a dedicated controller which just edits [Admin::]Encounters by
# updating the 'category_position' values in matching records. It doesn't
# use the acts-as-list movement API since multiple matching rows need to
# be updated together (due to quick-and-sort-of-easy data modelling).
#
class Admin::MoveEncountersController < ApplicationController

  before_action :authenticate_admin_user! # (via Devise)

  def update
    encounter = Encounter.find(params[:id])

    new_position = if params.key?(:higher)
      encounter.category_position - 1
    elsif params.key?(:lower)
      encounter.category_position + 1
    else
      return # NOTE EARLY EXIT
    end

    Encounter.transaction do

      # Push any records at the intended new position "out of the way".
      #
      if Encounter.where(category_position: new_position).any?
        if params.key?(:higher)
          Encounter
            .where("category_position = ?", new_position)
            .update_all("category_position = category_position + 1")
        else
          Encounter
            .where("category_position = ?", new_position)
            .update_all("category_position = category_position - 1")
        end
      end

      # Set the new position for the matching encounter collection.
      #
      Encounter
        .matching_category(encounter.category)
        .update_all(category_position: new_position)

      # "Rebase" all positions to start from 1, if they don't already.
      #
      delta = 1 - Encounter.minimum(:category_position)

      unless delta.zero?
        Encounter.update_all("category_position = category_position + #{delta}")
      end
    end # "Encounter.transaction do"

    redirect_to admin_encounters_path()
  end
end
