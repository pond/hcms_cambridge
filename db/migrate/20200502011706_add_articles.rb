class AddArticles < ActiveRecord::Migration[5.2]
  def change
    create_table :articles do | t |
      t.text    :title,              :null => false
      t.text    :slug,               :null => false, :index => { :unique => true }
      t.text    :article_hero_image, :null => false
      t.text    :summary,            :null => false
      t.text    :body,               :null => false
      t.boolean :raw_editor,         :null => false, :default => false

      t.belongs_to :page

      t.timestamps :null => false
    end
  end
end
