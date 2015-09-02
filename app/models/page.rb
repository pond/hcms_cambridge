class Page < ActiveRecord::Base
  belongs_to :page
  has_many :pages
  alias_method :children, :pages

  acts_as_list :scope => :page

  validates_presence_of :title, :body

  default_scope -> { order( :position => :asc ) }
  scope :top_level, -> { where( :page_id => nil  ) }
  scope :for_navigation, -> { where( :hidden => false ) }

  def self.top_level_except( exceptions = nil )
    array = [ exceptions ].flatten
    self.top_level().to_a - array
  end
end
