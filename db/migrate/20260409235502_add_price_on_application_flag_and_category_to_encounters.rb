class AddPriceOnApplicationFlagAndCategoryToEncounters < ActiveRecord::Migration[8.1]
  def change
    add_column :encounters, :price_on_application, :boolean, null: false, default: false
    add_column :encounters, :category, :text
    add_column :encounters, :category_position, :integer, null: false, default: 1
  end
end
