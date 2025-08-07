class PageImpression < ApplicationRecord
  def self.record!(path)
    self.create!(path: path)
  end
end
