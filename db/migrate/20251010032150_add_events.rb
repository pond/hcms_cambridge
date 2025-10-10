class AddEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do | t |
      t.timestamps null: false

      # This part looks very like an Article.

      t.text    :title,            null: false
      t.text    :slug,             null: false, index: { unique: true }
      t.text    :event_hero_image, null: false
      t.text    :summary,          null: false
      t.text    :body,             null: false
      t.boolean :raw_editor,       null: false, default: false

      t.belongs_to :page

      # This part is specific to Events.

      t.datetime :starts_at,       null: false
      t.datetime :ends_at,         null: false
      t.integer  :number_of_seats, null: false # 0 -> unlimited
      t.integer  :price_per_seat,  null: false # 0 -> free
      t.text     :currency,        null: false
      t.jsonb    :upon_archiving,  null: true
      t.boolean  :archived,        null: false, default: false, index: true
    end
  end
end
