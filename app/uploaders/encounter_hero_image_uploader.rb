class EncounterHeroImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  # Override the directory where uploaded files will be stored.
  def store_dir
    "system/redactor_assets/encounter_hero_images/#{model.id}"
  end

  # Allow-list of extensions which are allowed to be uploaded.
  def extension_white_list
    Redactor3Rails.images_file_types
  end
end
