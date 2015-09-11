class AddRawFlagToPage < ActiveRecord::Migration
  def change
    add_column :pages, :raw_editor, :boolean, :null => false, :default => false
  end
end
