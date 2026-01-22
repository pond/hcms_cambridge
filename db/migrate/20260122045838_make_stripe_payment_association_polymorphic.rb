class MakeStripePaymentAssociationPolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_column :stripe_payments, :payable_type, :string
    StripePayment.update_all(payable_type: 'Order')
    rename_column :stripe_payments, :order_id, :payable_id
  end

  def down
    rename_column :stripe_payments, :payable_id, :order_id
    remove_column :stripe_payments, :payable_type
  end
end
