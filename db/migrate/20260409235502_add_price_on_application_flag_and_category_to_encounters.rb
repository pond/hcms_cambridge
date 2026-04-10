class AddPriceOnApplicationFlagAndCategoryToEncounters < ActiveRecord::Migration[8.1]
  def change
    add_column :encounters, :price_on_application, :boolean, null: false, default: false

    # This is cheap modelling as arguably we should have EncounterCategory for
    # unique category position, but the table is likely to have very few records
    # and the UI handles management of position well enough to avoid the need
    # for anything more complex.
    #
    add_column :encounters, :category,          :text,    null: false, default: ""
    add_column :encounters, :category_position, :integer, null: false, default: 1

    add_index :encounters, [:category, :category_position]
  end
end
