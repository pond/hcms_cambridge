class AddSlugs < ActiveRecord::Migration[5.2]
  def change
    change_table :pages do | t |
      t.text :slug, :null => false, :default => ''
    end

    pairs = Page.pluck(:id, :title)
    pairs.each do | id, title |
      Page.find(id).update_column(:slug, title.parameterize)
    end
  end
end
