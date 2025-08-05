# A blog article. Attached to Pages of type "blog".
#
class Article < Editable
  mount_uploader :article_hero_image, ArticleHeroImageUploader

  belongs_to :page

  default_scope -> { order(created_at: :desc) }

  scope :for_navigation, -> {
    where(id: Revision.published.where(revisable_type: 'Article').select(:revisable_id))
  }

  validates_presence_of :article_hero_image, :summary, :body

  def is_article?
    true
  end

  def for_navigation?
    self.published_revision.present?
  end
end
