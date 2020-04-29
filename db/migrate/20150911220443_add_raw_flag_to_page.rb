class AddRawFlagToPage < ActiveRecord::Migration[4.2]
  def change
    add_column :pages, :raw_editor, :boolean, :null => false, :default => false
  end
end
