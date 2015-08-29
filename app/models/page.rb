class Page < ActiveRecord::Base
  belongs_to :page
  validates_presence_of :title, :body

  default_scope -> { order( :created_at => :asc ) }
  scope :top_level, -> { where( :page_id => nil ) }

  def self.top_level_except( exceptions = nil )
    array = [ exceptions ].flatten
    self.top_level().to_a - array
  end

  def children
    Page.where( :page_id => self.id )
  end
end
