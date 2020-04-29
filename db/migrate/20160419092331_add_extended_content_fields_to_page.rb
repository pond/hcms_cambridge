class AddExtendedContentFieldsToPage < ActiveRecord::Migration[4.2]
  def change
    add_column :pages, :page_type,                    :string, :null => false, :default => Page::PAGE_TYPE_NORMAL
    add_column :pages, :form_selection_list_contents, :text,   :null => false, :default => ''
  end
end
