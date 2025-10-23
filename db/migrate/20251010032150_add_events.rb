class AddEvents < ActiveRecord::Migration[8.0]
  def change
    create_enum :event_states,             Event::STATES
    create_enum :event_on_archive_actions, Event::ON_ARCHIVE_ACTIONS

    create_table :events do | t |
      t.timestamps null: false

      # This part looks very like an Article. Remember, title, body and summary
      # data are all kept in revisions.

      t.text    :slug,             null: false, index: { unique: true }
      t.text    :event_hero_image, null: false
      t.boolean :raw_editor,       null: false, default: false

      t.belongs_to :page

      # This part is specific to Events.

      t.datetime :starts_at,       null: false
      t.datetime :ends_at,         null: false
      t.integer  :number_of_seats, null: false # 0 -> unlimited
      t.integer  :price_per_seat,  null: false # 0 -> free; integer smallest currency units
      t.text     :location,        null: true  # Main description can include this instead
      t.string   :currency,        null: false, limit: 3

      t.enum     :state, enum_type: :event_states, null: false, default: Event.states[:presales], index: :true

      t.enum     :on_archive_action, enum_type: :event_on_archive_actions, null: false, default: Event.on_archive_actions[:keep]
      t.jsonb    :on_archive_params,                                       null: false, default: {}
    end
  end
end
