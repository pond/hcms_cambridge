class Page < ApplicationRecord
  belongs_to :page, optional: true
  has_many :pages
  alias_method :children, :pages

  before_save :assign_slug

  def assign_slug
    self.slug = (self.title || '').parameterize if self.slug.blank?
  end

  acts_as_list :scope => :page

  validates_presence_of :title, :body

  default_scope -> { order( :position => :asc ) }
  scope :top_level, -> { where( :page_id => nil  ) }
  scope :for_navigation, -> { where( :hidden => false ) }

  IS_INTEGER             = /\A\d+\z/
  PAGE_TYPE_NORMAL       = 'normal'
  PAGE_TYPE_BOOKING_FORM = 'booking_form'
  PAGE_TYPE_CONTACT_FORM = 'contact_form'
  PAGE_TYPES             =
  [
    OpenStruct.new( { :internal_type => PAGE_TYPE_NORMAL,       :human_text => 'Normal page' } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_BOOKING_FORM, :human_text => '"Booking" form' } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_CONTACT_FORM, :human_text => '"Contact us" form' } )
  ]

  def self.top_level_except( exceptions = nil )
    array = [ exceptions ].flatten
    self.top_level().to_a - array
  end

  def self.find_by_id_or_slug!( thing )
    if IS_INTEGER.match?( thing )
      self.find( thing )
    else
      self.find_by_slug!( thing )
    end
  end

  def is_normal_type?
    self.page_type == PAGE_TYPE_NORMAL
  end

  def is_form_type?
    self.page_type == PAGE_TYPE_BOOKING_FORM || self.page_type == PAGE_TYPE_CONTACT_FORM
  end
end
