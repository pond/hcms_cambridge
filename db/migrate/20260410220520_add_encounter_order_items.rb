# Optional additions to an EncounterOrder for a price-on-application Encounter.
#
class AddEncounterOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :encounter_order_items do | t |
      t.timestamps null: false

      t.belongs_to :encounter_order, type: :uuid, null: false

      t.text    :description, null: false
      t.integer :amount_owed, null: false # integer smallest currency units
    end
  end
end
