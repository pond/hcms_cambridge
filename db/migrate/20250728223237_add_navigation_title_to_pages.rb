class AddNavigationTitleToPages < ActiveRecord::Migration[7.2]
  def change
    change_table :pages do | t |
      t.text :navigation_title
    end

    Page.reset_column_information
  end
end
