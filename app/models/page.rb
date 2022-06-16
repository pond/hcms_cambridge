class Page < ActsLikePage

  belongs_to :page, optional: true
  has_many :pages

  alias_method :children, :pages
  alias_method :parent,   :page

  has_many :articles, dependent: :destroy

  before_validation do
    generate_unique_slug() if self.slug.blank? # see ApplicationRecord
  end

  acts_as_list :scope => :page

  validates_presence_of :title
  validates_presence_of :body, :unless => :is_blog_type?
  validates_uniqueness_of :slug

  default_scope -> { order( :position => :asc ) }
  scope :top_level, -> { where( :page_id => nil  ) }
  scope :for_navigation, -> { where( :hidden => false ) }

  PAGE_TYPE_NORMAL       = 'normal'
  PAGE_TYPE_BLOG         = 'blog'
  PAGE_TYPE_BOOKING_FORM = 'booking_form'
  PAGE_TYPE_CONTACT_FORM = 'contact_form'
  PAGE_TYPES             =
  [
    OpenStruct.new( { :internal_type => PAGE_TYPE_NORMAL,       :human_text => 'Normal page'       } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_BLOG,         :human_text => 'Blog'              } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_BOOKING_FORM, :human_text => '"Booking" form'    } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_CONTACT_FORM, :human_text => '"Contact us" form' } )
  ]

  def self.home
    Page.top_level.order(:created_at => :asc).first
  end

  def self.top_level_except( exceptions = nil )
    array = [ exceptions ].flatten
    self.top_level().to_a - array
  end

  def is_normal_type?
    self.page_type == PAGE_TYPE_NORMAL
  end

  def is_form_type?
    self.page_type == PAGE_TYPE_BOOKING_FORM || self.page_type == PAGE_TYPE_CONTACT_FORM
  end

  def is_blog_type?
    self.page_type == PAGE_TYPE_BLOG
  end

  # Is this page 'normal' type, with at least one child all also of 'normal'
  # type? If so, it can be converted to a blog so return +true+; else +false+.
  #
  def can_convert_to_blog?
    return (
      self.page_type == PAGE_TYPE_NORMAL &&
      self.children.count > 0 &&
      children.where.not(page_type: Page::PAGE_TYPE_NORMAL).none?
    )
  end

  # Attempt to summarise body content by retrieving the first non-header
  # sentence; usually used for Page -> blog Article auto-conversion.
  #
  def summarise
    headerless = self.body.gsub(/\<h\d.*?\>.*?\<\/h\d\>/m, '')
    summary    = ActionView::Base.full_sanitizer.sanitize(headerless).strip.match(/^(.+?)[\.\r\n]/m)&.captures&.first || self.title

    return "#{ summary }."
  end

  # Used by #find_first_image_uploader to find URLs in Redactor body text
  # which lead to asset IDs, from which an image uploader instance can be
  # generated.
  #
  IMAGE_UPLOADER_SIGNATURE = Regexp.quote('/system/redactor_assets/pictures/')

  # Return a Redactor3RailsImageUploader instance for the first image uploaded
  # in the Redactor body content of this page. This can then be assigned as the
  # image for another entity, usually for Page -> blog Article auto-conversion.
  # Returns +nil+ if none is found.
  #
  def find_first_image_uploader
    matches = self.body.match(/#{IMAGE_UPLOADER_SIGNATURE}(\d+)/)
    return nil unless matches.present?

    first_page_image_id = matches.captures.first
    return nil unless first_page_image_id.present?

    return Redactor3Rails::Image.find_by_id(first_page_image_id)&.data
  end
end
