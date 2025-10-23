class Event < Editable

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  enum(
    :state,
    {
      presales:           'presales',
      reservee_purchases: 'reservee_purchases',
      public_purchases:   'public_purchases',
      archived:           'archived',
    },
    prefix:  true,
    default: :presales,
  )

  STATES = self.states.keys

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  enum(
    :on_archive_action,
    {
      keep: 'keep', # Ends up in 'past events' subsection on event page
      hide: 'hide', # All revisions move into draft state
      move: 'move', # Convert and move to blog indicated by archive params
    },
    prefix:  true,
    default: :keep,
  )

  ON_ARCHIVE_ACTIONS = self.on_archive_actions.keys

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
    starts_at
    ends_at
    state
    on_archive_action
  }

  validates :starts_at,        comparison: { greater_than: -> { Time.current }, message: 'must be in the future' }
  validates :ends_at,          comparison: { greater_than: -> { Time.current }, message: 'must be in the future' }
  validates :state,             inclusion: { in: STATES,                        message: 'is not recognised'     }
  validates :on_archive_action, inclusion: { in: ON_ARCHIVE_ACTIONS,            message: 'is not recognised'     }

  after_initialize(unless: :persisted?) do
    tz_now = Time.current

    self.starts_at = tz_now.beginning_of_day +  9.hours
    self.ends_at   = tz_now.beginning_of_day + 17.hours
    self.currency  = Hcms.config.currency
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
        orders = Order.where(event: self, state: [Order.states[:new], Order.states[:successful]])
        [0, self.number_of_seats - orders.count].max()
      end
    end
  end
end
