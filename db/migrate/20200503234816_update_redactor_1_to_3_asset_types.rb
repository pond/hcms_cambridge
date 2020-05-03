class UpdateRedactor1To3AssetTypes < ActiveRecord::Migration[5.2]
  def up
    Redactor3Rails::Asset.where(type: 'RedactorRails::Picture' ).update_all(type: 'Redactor3Rails::Image')
    Redactor3Rails::Asset.where(type: 'RedactorRails::Document').update_all(type: 'Redactor3Rails::File' )
  end

  def down
    # Not reversible
  end
end
