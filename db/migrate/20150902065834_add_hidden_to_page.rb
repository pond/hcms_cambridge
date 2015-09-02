class AddHiddenToPage < ActiveRecord::Migration
  def change
    add_column :pages, :hidden, :boolean, :null => false, :default => false
  end
end
