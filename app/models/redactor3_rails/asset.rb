class Redactor3Rails::Asset < ApplicationRecord
  include Redactor3Rails::Orm::ActiveRecord::AssetBase

  delegate :url, :current_path, :size, :content_type, :filename, :to => :data
  validates_presence_of :data
end
