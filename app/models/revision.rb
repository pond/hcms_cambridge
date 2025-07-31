# A polymorphic relation attached to any Editable (e.g. Page, Article) which
# defines a revision. Only one revision in an ownership collection is ever in
# a non-draft state. This is not necessarily the most recent, as rollbacks do
# not automatically destroy newer records - they just set the rolled-to item
# non-draft and all other items draft. Adding a new revision after that would
# replace the chain.
#
# Think of it like a tape deck; you can be playing the tape, stop and rewind,
# then play from earlier and keep replaying that tape; but if you hit Record,
# you'll start overwriting everything from that position onwards.
#
# If using this model, use a "has_many" association with a name of "revisions".
#
class Revision < ApplicationRecord
  belongs_to :revisable, polymorphic: true

  default_scope -> { order( created_at: :desc ) }

  scope :draft, -> { where(draft: true) }
  scope :published, -> { where(draft: false) }

  # Columns (as Strings) which can be merged in from owning records. Might be
  # used to e.g. create a Revision temporarily from a Page's revisable
  # attributes - title, body and navigation_title.
  #
  REVISABLE_ATTRIBUTES = %W{title body navigation_title summary}

  # Finds the assumed-only record that's in a published state and returns it,
  # using no memoisation and potentially a DB query each time. Returns +nil+ if
  # there is no published revision. See also ::current_revision_in_array
  #
  # Call via a relation, e.g. via "page.revisions.current_revision_by_scope".
  #
  def self.current_revision_by_scope
    published.first # (order is created-at DESC by Revision default_scope)
  end

  # Given an array of Revision instances, returns the first found that is in a
  # published state. Appropriate array ordering is assumed. No DB queries made.
  # See also ::current_revision_by_scope.
  #
  def self.current_revision_in_array(revisions)
    revisions.find { |revision| !revision.hidden } # (order is created-at DESC by Revision default_scope)
  end

  # ============================================================================
  # UTILITY METHODS FOR OWNED RECORDS
  #
  # These methods only work once a Revision has been added to its owning
  # "revisable"'s "revisions" scope.
  # ============================================================================

  # (Presses Record)
  #
  # Sets this record to non-draft. If there is another published record in the
  # owned chain, then all newer Revisions (other than this one) are destroyed
  # and that previously published record is set to draft state.
  #
  # Callback are invoked for all operations *except* the record deletion.
  #
  def publish!
    Revision.transction do
      already_published = self.revisable.revisions.current_revision_by_scope()

      if already_published.present?
        self.revisable.revisions
          .where("created_at > ?", already_published.created_at)
          .where.not(id: self.id)
          .delete_all # (no callbacks; fast DB operation)

        already_published.update!(draft: false)
      end

      self.update!(draft: false)
    end
  end

  # (Rewinds the tape)
  #
  # Sets all Revisions in the owning chain to draft except this one, which
  # becomes published. Callbacks are invoked for all operations so that the
  # updated-at times on marked-draft records are updated.
  #
  def rollback!
    Revision.transaction do
      already_published = self.revisable.revisions.current_revision_by_scope()
      already_published.update!(draft: true)

      self.update!(draft: false)
    end
  end
end
