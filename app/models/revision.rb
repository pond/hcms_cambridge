# A polymorphic relation attached to any Editable (e.g. Page, Article) which
# defines a revision of the contents of that Editable thing.
#
# If using this model, use a "has_many" association with a name of "revisions".
#
# * In any collection owned by the Editable, only one item can ever be
#   published (visible on the public-facing site). Otherwise, items are
#   unpublished (historic or future). We thus support arbitrary rollback to any
#   prior item, simply by setting any Revision in the chain as 'published'.
#
# * The more complex management is for the 'current' Revision. This is the
#   one you see if you edit the Editable. When something is published, it
#   becomes 'current'. If you then save changes, a new Revision is built in
#   usually an unpublished state; this record is now 'current', so that future
#   edits continue to work on that Revision.
#
# Even if rolling back to publish an item from the middle of a Revision history
# you then end up with that item current and, if subsequently editing it, do
# edit that published version (not some random other Revision from the history
# which is presumed effectively abandoned by rollback). When saving those edits
# as a new Revision, this becomes current so that edits continue to work on
# that item until published, again, not on anything else in the history.
#
# Note the default scope that always orders newest-revision-first.
#
class Revision < ApplicationRecord
  belongs_to :revisable, polymorphic: true

  default_scope -> { order( created_at: :desc ) }

  scope :published, -> { where(published: true ) }
  scope :current,   -> { where(current:   true ) }

  # Columns (as Strings) which can be merged in from owning records. Might be
  # used to e.g. create a Revision temporarily from a Page's revisable
  # attributes - title, body and navigation_title.
  #
  REVISABLE_ATTRIBUTES = %W{title body navigation_title summary}

  # Whenever a record is about to save with callbacks, mark it as 'current'.
  #
  before_save do
    self.current = true
  end

  # After a record saves, manage flag exclusivity. IMPORTANT: Note the use of
  # "update_all" -> direct SQL updates, no callbacks; that's the only way it
  # is safe within an after-save hook *and* avoids things like the above
  # "mark it current" before-save callback.
  #
  after_save do
    self.revisable.revisions.current
      .where.not(id: self.id)
      .update_all(current: false, updated_at: self.updated_at)

    if self.published?
      self.revisable.revisions.published
        .where.not(id: self.id)
        .update_all(published: false, updated_at: self.updated_at)
    end
  end

  # Finds the assumed-only record that's in a published state and returns it,
  # using no memoisation and potentially a DB query each time. Returns +nil+ if
  # there is no published revision. See also ::published_revision_in_array
  #
  # Call via a relation, e.g. via "page.revisions.published_revision_by_scope".
  #
  def self.published_revision
    published.first
  end

  # Analogous to ::published_revision, but for the current Revision; should
  # never return +nil+ (unless data is broken!).
  #
  def self.current_revision
    current.first
  end
end
