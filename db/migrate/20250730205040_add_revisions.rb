class AddRevisions < ActiveRecord::Migration[8.0]
  def change
    create_table :revisions do | t |
      t.timestamps
      t.references :revisable, polymorphic: true, null: false

      t.text :title
      t.text :navigation_title
      t.text :summary
      t.text :body

      t.boolean :draft, default: true
    end

    add_index :revisions, :draft
  end
end
