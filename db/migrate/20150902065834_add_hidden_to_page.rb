class AddHiddenToPage < ActiveRecord::Migration[4.2]
  def change
    add_column :pages, :hidden, :boolean, :null => false, :default => false
  end
end
