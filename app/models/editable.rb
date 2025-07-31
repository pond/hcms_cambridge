class Editable < ApplicationRecord
  self.abstract_class = true

  IS_INTEGER = /\A\d+\z/

  has_many :revisions, as: :revisable, dependent: :destroy

  # Delegation is usually obtuse! In this case, it is even more thorny - you
  # should only use this for forms. Allowing a form to act upon a single model
  # class and just delegating certain properties down into a Revision makes
  # life simpler everywhere else.
  #
  # * When presenting a form, we always edit whatever is currently published if
  #   it exists, else whatever is the most recent draft revision.
  #
  # * When submitting the form, we want to write through to a new draft.
  #
  Revision::REVISABLE_ATTRIBUTES.each do | revisable_attribute |
    delegate revisable_attribute, to: :current_revision
    delegate "#{revisable_attribute}=", to: :draft_revision
  end

  # ===========================================================================
  # LIFECYCLE
  # ===========================================================================

  PersistenceResult = Struct.new(:successful, :published)

  # Unless you have special requirements, you shouldn't normally just call
  # standard persistence methods on an Editable, to save on boilerplate.
  #
  # This method cuts down on controller boilerplate accordingly; it assigns the
  # given (safe / strong parameters) attributes and optionally publishes. The
  # returned PersistenceResult explains the outcome.
  #
  def persist!(safe_attributes, publish:)
    result = PersistenceResult.new(successful: false, published: false)

    self.assign_attributes(safe_attributes)
    self.published = true if publish # (don't change to "false" if already "true")

    result.successful = self.save()
    result.published  = true if publish && result.successful

    return result
  end

  # ===========================================================================
  # UTILITIES
  # ===========================================================================

  # The published Revision. Might return +nil+. Memoised.
  #
  # This should be used for any editable "show"-like action without some other
  # prevailing revision ID in force.
  #
  def published_revision
    unless defined? @published_revision
      @published_revision = self.revisions.published_revision
    end

    @published_revision
  end

  # The current revision for reading in an edit form. Memoised.
  #
  def current_revision
    unless defined? @current_revision
      @current_revision = self.revisions.current_revision
    end

    @current_revision
  end

  # Returns a new Revision that represents a new writeable draft. Memoised.
  #
  def draft_revision
    @current_draft_revision ||= self.revisions.build
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
