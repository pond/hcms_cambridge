class AddAddressToOrder < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :address, :text, null: true
  end
end
