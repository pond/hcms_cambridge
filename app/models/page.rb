class Page < Editable
  belongs_to :parent, class_name: 'Page', foreign_key: 'page_id', optional: true
  has_many :children, class_name: 'Page'
  has_many :children_for_navigation, -> { for_navigation }, class_name: 'Page'
  has_many :articles, dependent: :destroy

  acts_as_list scope: :page
  default_scope -> { order(position: :asc) }

  scope :top_level,        -> { where(page_id: nil) }
  scope :top_level_except, -> (*id_or_ids) { top_level.where.not(id: id_or_ids) }
  scope :for_navigation,   -> {
    where(hidden: false)
    .where(id: Revision.published.where(revisable_type: 'Page').select(:revisable_id))
  }

  validates_presence_of :body, unless: :is_blog_type?

  PAGE_TYPE_NORMAL       = 'normal'
  PAGE_TYPE_BLOG         = 'blog'
  PAGE_TYPE_BOOKING_FORM = 'booking_form'
  PAGE_TYPE_CONTACT_FORM = 'contact_form'
  ORDERED_PAGE_TYPES     = [
    PAGE_TYPE_NORMAL,
    PAGE_TYPE_BOOKING_FORM,
    PAGE_TYPE_CONTACT_FORM,
    PAGE_TYPE_BLOG,
  ]

  def self.home
    Page.top_level.reorder(created_at: :asc).first # (whether or not it yet has a published revision)
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

  def for_navigation?
    ! self.hidden && self.published_revision.present?
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
end
