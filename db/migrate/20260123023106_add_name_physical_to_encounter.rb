class AddNamePhysicalToEncounter < ActiveRecord::Migration[8.1]
  def change
    add_column :encounters, :name_physical, :text
  end
end
