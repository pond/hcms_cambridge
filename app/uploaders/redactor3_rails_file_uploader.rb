# encoding: utf-8
class Redactor3RailsFileUploader < CarrierWave::Uploader::Base
  include Redactor3Rails::Backend::CarrierWave

  def store_dir
    "system/redactor_assets/documents/#{model.id}"
  end

  def extension_white_list
    Redactor3Rails.files_file_types
  end
end
