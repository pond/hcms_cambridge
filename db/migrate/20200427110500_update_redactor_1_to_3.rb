class UpdateRedactor1To3 < ActiveRecord::Migration[4.2]
  def self.change
    alter_table :redactor_assets do |t|
      t.string :custom_file_name
    end

  end

  def self.down
    drop_table :redactor_assets
  end
end
