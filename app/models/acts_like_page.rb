class ActsLikePage < ApplicationRecord
  self.abstract_class = true

  IS_INTEGER = /\A\d+\z/

  # ===========================================================================
  # UTILITIES
  # ===========================================================================

  # Uses the title to generate a slug, making sure it is unique.
  #
  def generate_unique_slug
    slug_base = (self.title || '').parameterize
    suffix    = ''
    counter   = 2

    while Page.where(slug: slug_base + suffix).any?
      suffix  = "-#{counter}"
      counter += 1
    end

    self.slug = slug_base + suffix
  end

  # Find an instance by ID or slug.
  #
  def self.find_by_id_or_slug!( thing )
    if IS_INTEGER.match?( thing )
      self.find( thing )
    else
      self.find_by_slug!( thing )
    end
  end

  # ===========================================================================
  # TRAITS
  #
  # Override a method to return +true+ if the subclass exhibits the  trait that
  # the method describes.
  # ===========================================================================

  def is_form_type?
    false
  end

  def is_normal_type?
    false
  end

  def is_blog_type?
    false
  end

  def is_article?
    false
  end
end
