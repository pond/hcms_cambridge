class AddInvoiceNumberToOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :orders, :invoice_number, :bigserial, null: false
    add_index  :orders, :invoice_number, unique: true

    # This won't work for people starting on a new database, but works for
    # people migrating existing data. See "db/seeds.rb" for just the sequence
    # reset.
    #
    starting_invoice_number = rand(1001..1499)
    execute <<~SQL
      ALTER SEQUENCE orders_invoice_number_seq RESTART WITH #{starting_invoice_number};
      UPDATE orders SET invoice_number = nextval('orders_invoice_number_seq');
    SQL
  end

  def down
    remove_column :orders, :invoice_number
  end
end
