class MakeStripePriceAssociationPolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_column :stripe_prices, :priceable_type, :string
    StripePrice.update_all(priceable_type: 'Event')
    rename_column :stripe_prices, :event_id, :priceable_id
  end

  def down
    rename_column :stripe_prices, :priceable_id, :event_id
    remove_column :stripe_prices, :priceable_type
  end
end
