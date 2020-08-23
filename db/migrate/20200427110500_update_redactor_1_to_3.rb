class UpdateRedactor1To3 < ActiveRecord::Migration[5.2]
  def self.change
    change_table :redactor_assets do |t|
      t.string :custom_file_name
    end
  end
end
