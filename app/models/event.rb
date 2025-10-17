class Event < Editable
  ON_ARCHIVE_KEEP = 'keep' # Ends up in 'past events' subsection on event page
  ON_ARCHIVE_HIDE = 'hide' # All revisions move into draft state
  ON_ARCHIVE_MOVE = 'move' # Convert and move to blog indicated by archive params

  ORDERED_ARCHIVING_ACTIONS = [
    ON_ARCHIVE_KEEP,
    ON_ARCHIVE_HIDE,
    ON_ARCHIVE_MOVE
  ]

  mount_uploader :event_hero_image, EventHeroImageUploader

  belongs_to :page

  default_scope -> { order(archived: :asc, starts_at: :asc) }

  scope :for_navigation, -> {
    where(id: Revision.published.where(revisable_type: 'Event').select(:revisable_id))
  }

  after_initialize do
    tz_now = Time.now.in_time_zone(Rails.application.config.uk_org_pond_hcms.time_zone || 'UTC')

    self.starts_at = tz_now.beginning_of_day +  9.hours
    self.ends_at   = tz_now.beginning_of_day + 17.hours
    self.currency  = Rails.application.config.uk_org_pond_hcms.currency

    self.on_archive_action = ON_ARCHIVE_KEEP
  end

  validates_presence_of %i{
    event_hero_image
    summary
    body
    currency
  }

  validates :starts_at,         presence: true, comparison: { greater_than: -> { Time.now }, message: 'must be in the future' }
  validates :ends_at,           presence: true, comparison: { greater_than: -> { Time.now }, message: 'must be in the future' }
  validates :on_archive_action, presence: true,  inclusion: { in: ORDERED_ARCHIVING_ACTIONS, message: 'is not recognised'     }

  def is_event?
    true
  end

  def for_navigation?
    self.published_revision.present?
  end

  # A newer event - next greater created_at. Assumes no two identical times.
  #
  def next
    @next ||= self.class
      .reorder(created_at: :asc)
      .where(page_id: self.page_id)
      .where('created_at > ?', self.created_at)
      .first
  end

  # An older event - next lower created_at. Assumes no two identical times.
  #
  def prev
    @prev ||= self.class
      .reorder(created_at: :desc)
      .where(page_id: self.page_id)
      .where('created_at < ?', self.created_at)
      .first
  end
end
