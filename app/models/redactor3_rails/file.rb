class Redactor3Rails::File < Redactor3Rails::Asset
  mount_uploader :data, Redactor3Rails.file_uploader, :mount_on => :data_file_name

  def url_content
    url(:content)
  end
end
