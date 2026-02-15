class AddStripePrices < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_prices do | t |
      t.timestamps                   null: false
      t.belongs_to :event,           null: false
      t.text       :stripe_price_id, null: false
    end
  end
end
