class Editable < ApplicationRecord
  self.abstract_class = true

  IS_INTEGER = /\A\d+\z/

  has_many :revisions, as: :revisable, autosave: true, dependent: :destroy

  before_validation do
    generate_unique_slug() if self.slug.blank? # see ApplicationRecord
  end

  validates_presence_of :title
  validates_uniqueness_of :slug

  # ============================================================================
  # DELEGATION
  # ============================================================================
  #
  # Various methods to read or write "revisable" attributes are delegated down
  # to Revision instances.
  #
  # * By default, an Editable record is set up for reading:
  #
  #   - Attribute reads use a published revision in favour of an unpublished
  #     current revision.
  #
  #   - Attempts to write delegated attributes will result in an error.
  #
  # * If #for_edit! is invoked just after the Editable is instantiated, then
  #   the record sets itself up for an editing context.
  #
  #   - Attribute reads use the current unpublished revision if there is one,
  #     else a published record, else for brand new records, a blank draft.
  #
  #   - Writes go to that current unpublished revision or the blank draft.
  #
  # * If #use_revision! is invoked then reads come from a specific given
  #   Revision, with an intent-to-edit assumption. Calling #for_edit! after
  #   #use_revision! is harmless but unnecessary.
  #
  #   - Attribute reads use the given revision.
  #
  #   - Writes will use the given revision if it is an unpublished, current
  #     draft; those usually only appear at the "end of the chain" and it makes
  #     sense to just continue editing that one. For all other cases, writes
  #     go to a new, unsaved, unpublished current draft.
  #
  def read_revision_for_delegation
    if @use_revision.present? # See #use_revision!
      @use_revision
    elsif @for_edit == true # See #for_edit!
      self.current_revision || self.published_revision || self.draft_revision
    else
      self.published_revision || self.current_revision
    end
  end

  def write_revision_for_delegation
    if @use_revision.present?
      if self.draft_revision != @use_revision # (self.draft_revision memoises into @draft_revision)
        self.revisions.each { | revision | revision.current = false }
        @draft_revision = self.revisions.build(
          self
            .attributes
            .slice(*Revision::REVISABLE_ATTRIBUTES)
            .merge(current: true)
        )
      end
      @draft_revision
    elsif @for_edit == true
      self.draft_revision
    else
      nil
    end
  end

  Revision::REVISABLE_ATTRIBUTES.each do | revisable_attribute |
    delegate revisable_attribute, to: :read_revision_for_delegation
    delegate "#{revisable_attribute}=", to: :write_revision_for_delegation
  end

  delegate :published=, to: :write_revision_for_delegation

  # See #read_revision_for_delegation documentation for details.
  #
  # Returns 'self' for convenience.
  #
  def for_edit!
    @for_edit = true
    return self
  end

  # See #read_revision_for_delegation documentation for details.
  #
  # Returns 'self' for convenience.
  #
  def use_revision!(revision)
    @use_revision = revision
    return self
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
    @published_revision ||= self.revisions.find(&:published)
  end

  # The current revision for reading in an edit form. Memoised.
  #
  def current_revision
    @current_revision ||= self.revisions.find(&:current)
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

  # Returns whatever Revision is being used for reading (for any purpose) via
  # delegation. Memoised.
  #
  def displayed_revision
    @displayed_revision ||= self.read_revision_for_delegation
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

  # Find an instance by ID (expressed as an Integer or String) or slug.
  #
  def self.find_by_id_or_slug!(thing)
    if thing.is_a?(Integer) || IS_INTEGER.match?(thing.to_s)
      self.find(thing)
    else
      self.find_by_slug!(thing)
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
