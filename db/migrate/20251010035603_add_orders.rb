class AddOrders < ActiveRecord::Migration[8.0]
  def up
    create_enum :order_status, Order::ORDER_STATES

    create_table :orders, id: :uuid do | t |
      t.timestamps null: false

      t.belongs_to :event, null: false

      t.text    :name,            null: false
      t.text    :email_address,   null: false
      t.text    :phone_number,    null: true
      t.text    :notes,           null: true
      t.integer :number_of_seats, null: false
      t.integer :amount_owed,     null: false # integer smallest currency units

      t.enum :status, enum_type: :order_status, null: false, default: Order::ORDER_STATE_NEW, index: :true
    end
  end

  def down
    drop_table :orders
    drop_enum :order_status
  end
end
