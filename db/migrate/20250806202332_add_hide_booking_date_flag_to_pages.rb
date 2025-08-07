class AddHideBookingDateFlagToPages < ActiveRecord::Migration[8.0]
  def change
    add_column :pages, :hide_date_and_time, :boolean, null: false, default: false
  end
end
