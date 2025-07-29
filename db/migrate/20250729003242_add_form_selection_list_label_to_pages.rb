class AddFormSelectionListLabelToPages < ActiveRecord::Migration[7.2]
  def change
    change_table :pages do | t |
      t.text :form_selection_list_label
    end
  end
end
