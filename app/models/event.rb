class Event < Editable
  EVENT_STATE_PRESALES           = "presales"
  EVENT_STATE_RESERVEE_PURCHASES = "reservee_purchases"
  EVENT_STATE_PUBLIC_PURCHASES   = "public_purchases"
  EVENT_STATE_ARCHIVED           = "archived"

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  EVENT_STATES = [
    EVENT_STATE_PRESALES,
    EVENT_STATE_RESERVEE_PURCHASES,
    EVENT_STATE_PUBLIC_PURCHASES,
    EVENT_STATE_ARCHIVED,
  ]

  ON_ARCHIVE_KEEP = 'keep' # Ends up in 'past events' subsection on event page
  ON_ARCHIVE_HIDE = 'hide' # All revisions move into draft state
  ON_ARCHIVE_MOVE = 'move' # Convert and move to blog indicated by archive params

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  ORDERED_ARCHIVING_ACTIONS = [
    ON_ARCHIVE_KEEP,
    ON_ARCHIVE_HIDE,
    ON_ARCHIVE_MOVE
  ]

  mount_uploader :event_hero_image, EventHeroImageUploader

  belongs_to :page

  default_scope -> { order(starts_at: :asc) }

  scope :for_navigation, -> {
    where(id: Revision.published.where(revisable_type: 'Event').select(:revisable_id))
  }

  validates_presence_of %i{
    event_hero_image
    summary
    body
    currency
  }

  validates :starts_at,         presence: true, comparison: { greater_than: -> { Time.current }, message: 'must be in the future' }
  validates :ends_at,           presence: true, comparison: { greater_than: -> { Time.current }, message: 'must be in the future' }
  validates :on_archive_action, presence: true,  inclusion: { in: ORDERED_ARCHIVING_ACTIONS,     message: 'is not recognised'     }

  after_initialize(unless: :persisted?) do
    tz_now = Time.current

    self.starts_at = tz_now.beginning_of_day +  9.hours
    self.ends_at   = tz_now.beginning_of_day + 17.hours
    self.currency  = Rails.application.config.uk_org_pond_hcms.currency

    self.state             = EVENT_STATE_PRESALES
    self.on_archive_action = ON_ARCHIVE_KEEP
  end

  def is_event?
    true
  end

  def for_navigation?
    self.published_revision.present?
  end

  def collapse_metadata_in_form?
    ! self.new_record? && self.valid?
  end

  # A closer event - next lower starts_at. Assumes no two identical times.
  #
  def next
    @next ||= self.class
      .reorder(created_at: :desc)
      .where(page_id: self.page_id)
      .where('starts_at < ?', self.starts_at)
      .first
  end

  # A more distant event - next greater starts_at. Assumes no two identical times.
  #
  def prev
    @prev ||= self.class
      .reorder(created_at: :asc)
      .where(page_id: self.page_id)
      .where('starts_at > ?', self.starts_at)
      .first
  end

  # An at-the-instant estimate; returns +nil+ if seat count is unlimited.
  #
  def seats_remaining
    if self.number_of_seats.zero?
      return nil
    else
      @seats_remaining ||= begin
        # TODO: Created-at within expiry window for NEW status / expiry concept finalisation
        orders = Order.where(event: self, state: [Order::ORDER_STATE_NEW, Order::ORDER_STATE_SUCCESS])
        [0, self.number_of_seats - orders.count].max()
      end
    end
  end
end
