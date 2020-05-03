class ArticleHeroImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  # Override the directory where uploaded files will be stored.
  def store_dir
    "system/redactor_assets/article_hero_images/#{model.id}"
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    Redactor3Rails.images_file_types
  end
end
