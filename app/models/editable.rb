class Editable < ApplicationRecord
  self.abstract_class = true

  IS_INTEGER = /\A\d+\z/

  has_many :revisions, as: :revisable, autosave: true, dependent: :destroy

  # Delegation:
  #
  # * If this record is generic, then we read from whatever is published by
  #   default, but if that's missing, go for a current draft. Read-only.
  #
  # * If the record is using an overridden revision, read from that.
  #
  # * If the record is intended for editing, we reverse read order; continue on
  #   a current draft, or fall back to reading from the current published copy.
  #   For writing, we write into the current unpublished draft or build a new
  #   one if need be.
  #
  after_initialize do
    @read_revision_for_delegation = self.published_revision || self.current_revision
    @write_revision_for_delegation = nil
  end

  def use_revision!(revision)
    @read_revision_for_delegation = revision
    return self
  end

  def for_edit!
    @read_revision_for_delegation = self.current_revision || self.published_revision || self.draft_revision
    @write_revision_for_delegation = self.draft_revision
    return self
  end

  Revision::REVISABLE_ATTRIBUTES.each do | revisable_attribute |
    delegate revisable_attribute, to: :@read_revision_for_delegation
    delegate "#{revisable_attribute}=", to: :@write_revision_for_delegation
  end

  delegate :published=, to: :@write_revision_for_delegation

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

    if result.successful
      result.published = true if publish
      self.revisions.reload
      @current_revision = @published_revision = @draft_revision = nil
    end

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
    @published_revision ||= self.revisions.load.find(&:published)
  end

  # The current revision for reading in an edit form. Memoised.
  #
  def current_revision
    @current_revision ||= self.revisions.load.find(&:current)
  end

  # Returns a new Revision that represents a writeable draft. Memoised.
  #
  def draft_revision
    @draft_revision ||= begin
      revision = self.current_revision
      revision = self.revisions.build(current: true) if revision.nil? || revision.published
      revision
    end
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

  def appears_in_navigation?
    false
  end
end
