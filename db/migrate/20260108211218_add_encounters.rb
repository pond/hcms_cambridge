class AddEncounters < ActiveRecord::Migration[8.1]
  def change
    create_table :encounters do | t |
      t.timestamps null: false

      # This part looks a bit like an Article. Remember, title, body and summary
      # data are all kept in revisions.

      t.text    :slug,                 null: false, index: { unique: true }
      t.text    :encounter_hero_image, null: false
      t.boolean :raw_editor,           null: false, default: false

      # This part is specific to Encounters.

      t.text    :location,        null: true  # Main description can include this instead
      t.integer :price_per_seat,  null: false # 0 -> free; integer smallest currency units
      t.integer :price_physical,  null: true  # Price of a physical gift voucher, or NULL if none offered
      t.string  :currency,        null: false, limit: 3
    end
  end
end
