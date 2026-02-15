# A blog article. Attached to Pages of type "blog".
#
class Article < Editable
  mount_uploader :article_hero_image, ArticleHeroImageUploader

  belongs_to :page

  default_scope -> { order(created_at: :desc) }

  scope :for_navigation, -> {
    where(id: Revision.published.where(revisable_type: 'Article').select(:revisable_id))
  }

  validates_presence_of :summary, :body
  validates :article_hero_image, presence: true, on: :create

  def is_article?
    true
  end

  def for_navigation?
    self.published_revision.present?
  end

  def collapse_metadata_in_form?
    ! self.new_record? && self.valid?
  end

  # A newer article - next greater created_at. Assumes no two identical times.
  #
  def next
    @next ||= self.class
      .for_navigation
      .reorder(created_at: :asc)
      .where(page_id: self.page_id)
      .where('created_at > ?', self.created_at)
      .first
  end

  # An older article - next lower created_at. Assumes no two identical times.
  #
  def prev
    @prev ||= self.class
      .for_navigation
      .reorder(created_at: :desc)
      .where(page_id: self.page_id)
      .where('created_at < ?', self.created_at)
      .first
  end
end
