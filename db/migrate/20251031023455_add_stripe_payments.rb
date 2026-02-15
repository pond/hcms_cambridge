class AddStripePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_payments do | t |
      t.timestamps                         null: false
      t.belongs_to :order,                 null: false, type: :uuid
      t.text       :stripe_payment_intent, null: false
    end
  end
end
