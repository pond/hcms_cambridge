class UpdateRedactor1To3 < ActiveRecord::Migration[5.2]
  def self.up

    # Table name may be unexpected, depending on exact Redactor setup.
    #
    rename_table :redactor2_assets, :redactor_assets rescue nil

    change_table :redactor_assets do |t|
      t.string :custom_file_name
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
