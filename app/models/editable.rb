class Editable < ApplicationRecord
  self.abstract_class = true

  IS_INTEGER = /\A\d+\z/

  has_many :revisions, as: :revisable, dependent: :destroy

  # Delegate top-level title, body etc. methods down to the current revision.
  #
  Revision::REVISABLE_ATTRIBUTES.each do | revisable_attribute |
    delegate revisable_attribute, to: :current_revision # (see method later in this file)
  end

  # ===========================================================================
  # UTILITIES
  # ===========================================================================

  # The most recent non-draft revision. Revisions might be eager-loaded, so
  # uses a Ruby-only check for small revisions, falling back to the database
  # for larger revision counts.
  #
  # If there is no non-draft revision but there are revisions present, then we
  # assume this editable item has no published aspect and return the most
  # recent *draft* instead.
  #
  # TODO: MIGRATE AND DELETE THIS:
  # If all else fails, legacy inline data is used to construct a temporary
  # Revision instance that's not persisted; this is returned.
  #
  # Compared with Revision::current_revision chained into a scope, this takes
  # advantage of eager-loading **and memoises the result for this Page** (so
  # beware changing Revisions and then referencing this method for the same
  # instance of the owning page, as the result will not be updated).
  #
  def current_revision
    @current_revision ||= if self.revisions.loaded? && self.revisions.size < 100
      Revision.current_revision_in_array(self.revisions)
    else
      self.revisions.current_revision_by_scope()
    end

    if @current_revision.nil?
      @current_revision = self.revisions.first # (order is created-at DESC by Revision default_scope)
    end

    if @current_revision.nil?
      @current_revision = Revision.new(self.attributes.slice("created_at", "updated_at", *Revision::REVISABLE_ATTRIBUTES))
      @current_revision.revisable  = self
    end

    @current_revision
  end

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
