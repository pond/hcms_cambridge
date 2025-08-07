class AddPageImpressions < ActiveRecord::Migration[8.0]
  def change
    create_table :page_impressions do | t |
      t.datetime :created_at, null: false
      t.text     :path,       null: false
      t.text     :referrer,   null: true
      t.text     :controller, null: false
      t.text     :action,     null: false
      t.jsonb    :params,     null: false
      t.integer  :status,     null: false
    end

    add_index :page_impressions, :path
  end
end
