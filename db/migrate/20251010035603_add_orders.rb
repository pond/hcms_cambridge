class AddOrders < ActiveRecord::Migration[8.0]
  def change
    create_enum :order_states, Order::STATES

    create_table :orders, id: :uuid do | t |
      t.timestamps null: false

      t.belongs_to :event, null: false

      t.text    :name,            null: false
      t.text    :email,           null: false
      t.text    :phone_number,    null: true
      t.text    :notes,           null: true
      t.integer :number_of_seats, null: false
      t.integer :amount_owed,     null: false # integer smallest currency units
      t.text    :token,           null: false # via Rails 'has_secure_token' in model

      t.enum :state, enum_type: :order_states, null: false, default: Order.states[:new], index: :true
    end
  end
end
