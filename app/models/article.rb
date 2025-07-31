# A blog article. Attached to Pages of type "blog".
#
class Article < Editable
  mount_uploader :article_hero_image, ArticleHeroImageUploader

  belongs_to :page

  default_scope -> { order(created_at: :desc) }

  scope :for_navigation, -> {
    base_page_query   = unscope(:order)
    revision_subquery = Revision.published.where(revisable_type: 'Article').select(:revisable_id)

    with_published_revisions = base_page_query.    where(id: revision_subquery)
    with_no_revisions        = base_page_query.where.not(id: revision_subquery)

    from("(#{with_published_revisions.to_sql} UNION #{with_no_revisions.to_sql}) AS articles").order(created_at: :desc)
  }

  before_validation do
    generate_unique_slug() if self.slug.blank? # see ApplicationRecord
  end

  validates_presence_of :title, :slug, :article_hero_image, :summary, :body
  validates_uniqueness_of :slug

  def is_article?
    true
  end
end
