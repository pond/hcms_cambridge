# A blog article. Attached to Pages of type "blog".
#
class Article < ActsLikePage

  mount_uploader :article_hero_image, ArticleHeroImageUploader

  belongs_to :page
  default_scope -> { order( :created_at => :desc ) }

  before_validation do
    generate_unique_slug() if self.slug.blank? # see ApplicationRecord
  end

  validates_presence_of :title, :slug, :article_hero_image, :summary, :body
  validates_uniqueness_of :slug

  def is_article?
    true
  end
end
