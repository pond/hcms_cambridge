class Page < Editable
  belongs_to :page, optional: true
  has_many :pages
  has_many :articles, dependent: :destroy

  alias_method :children, :pages
  alias_method :parent,   :page

  acts_as_list :scope => :page
  default_scope -> { order(position: :asc) }

  scope :top_level, -> { where(page_id: nil) }
  scope :for_navigation, -> {
    base_page_query   = where(hidden: false).unscope(:order)
    revision_subquery = Revision.published.where(revisable_type: 'Page').select(:revisable_id)

    with_published_revisions = base_page_query.    where(id: revision_subquery)
    with_no_revisions        = base_page_query.where.not(id: revision_subquery)

    from("(#{with_published_revisions.to_sql} UNION #{with_no_revisions.to_sql}) AS pages").order(position: :asc)
  }

  before_validation do
    generate_unique_slug() if self.slug.blank? # see ApplicationRecord
  end

  validates_presence_of :title
  validates_presence_of :body, unless: :is_blog_type?
  validates_uniqueness_of :slug

  PAGE_TYPE_NORMAL       = 'normal'
  PAGE_TYPE_BLOG         = 'blog'
  PAGE_TYPE_BOOKING_FORM = 'booking_form'
  PAGE_TYPE_CONTACT_FORM = 'contact_form'
  PAGE_TYPES             =
  [
    OpenStruct.new( { :internal_type => PAGE_TYPE_NORMAL,       :human_text => 'Normal page'  } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_CONTACT_FORM, :human_text => 'Contact form' } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_BOOKING_FORM, :human_text => 'Booking form' } ),
    OpenStruct.new( { :internal_type => PAGE_TYPE_BLOG,         :human_text => 'Blog'         } ),
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

  def is_blog_type?
    self.page_type == PAGE_TYPE_BLOG
  end

  def is_form_type?
    self.is_contact_form? || self.is_booking_form?
  end

  def is_contact_form?
    self.page_type == PAGE_TYPE_CONTACT_FORM
  end

  def is_booking_form?
    self.page_type == PAGE_TYPE_BOOKING_FORM
  end

  def form_class
    if self.is_contact_form?
      Forms::Contact
    elsif self.is_booking_form?
      Forms::Booking
    else
      nil
    end
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
