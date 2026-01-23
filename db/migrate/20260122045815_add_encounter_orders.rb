# Note that this does intentionally reuse the "order_states" enum created
# originally by "20251010035603_add_orders.rb".
#
class AddEncounterOrders < ActiveRecord::Migration[8.1]
  def up
    create_table :encounter_orders, id: :uuid do | t |
      t.timestamps null: false

      t.belongs_to :encounter, null: false

      # Unlike Orders where most things are filled in by the person who wants
      # to attend an Event, an EncounterOrder is created and configured by the
      # admin, then sent to the Encounter attendee(s) for finalisation.
      #
      t.text      :name,            null: false
      t.text      :email,           null: false
      t.text      :phone_number,    null: true
      t.text      :address,         null: true

      t.text      :notes_to_buyer,  null: true
      t.text      :gift_note,       null: true
      t.boolean   :has_physical,    null: true  # tristate - true/false/nil
      t.datetime  :starts_at,       null: true  # nil => open-ended
      t.integer   :number_of_seats, null: false
      t.integer   :amount_owed,     null: false # integer smallest currency units

      t.text      :token,           null: false # via Rails 'has_secure_token' in model
      t.bigserial :invoice_number,  null: false, index: { unique: true }

      t.enum :state, enum_type: :order_states, null: false, default: EncounterOrder.states[:new], index: :true
    end

    starting_invoice_number = rand(1001..1499)

    execute <<~SQL
      ALTER SEQUENCE encounter_orders_invoice_number_seq RESTART WITH #{starting_invoice_number};
      UPDATE encounter_orders SET invoice_number = nextval('encounter_orders_invoice_number_seq');
    SQL
  end

  def down
    drop_table :encounter_orders
  end
end
