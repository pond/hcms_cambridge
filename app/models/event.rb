class Event < Editable
  include AASM

  mount_uploader :event_hero_image, EventHeroImageUploader

  belongs_to :page
  has_many :orders

  after_initialize(unless: :persisted?) do
    tz_now = Time.current

    self.starts_at = tz_now.beginning_of_day +  9.hours
    self.ends_at   = tz_now.beginning_of_day + 17.hours
    self.currency  = Hcms.config.currency
  end

  # ============================================================================
  # Enumerations (see also any AASM state machine definition(s) later)
  # ============================================================================

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  # Using 'enum' will cause Rails to generate a bunch of accessors which use
  # "enum_state_" as a prefix, to avoid collision with an AASM state machine
  # defined later, which uses "state_" as a prefix and should always be used
  # in favour of the enum-defined methods to cause state changes and so-on.
  #
  enum(
    :state,
    {
      presales:           'presales',
      reserver_purchases: 'reserver_purchases',
      public_purchases:   'public_purchases',
      archived:           'archived',
      cancelled:          'cancelled',
    },
    prefix:  'enum_state',
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

  # ============================================================================
  # Scopes
  # ============================================================================

  default_scope -> { order(starts_at: :asc) }

  scope :not_cancelled, -> {
    where.not(state: Event.states[:cancelled])
  }

  scope :for_navigation, -> {
    not_cancelled
      .where(id: Revision.published.where(revisable_type: 'Event')
      .select(:revisable_id))
  }

  # ============================================================================
  # Validations
  # ============================================================================

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

  # ============================================================================
  # Overrides of Editable base class
  # ============================================================================

  def is_event?
    true
  end

  def for_navigation?
    self.published_revision.present?
  end

  def collapse_metadata_in_form?
    ! self.new_record? && self.valid?
  end

  # ============================================================================
  # Navigation
  # ============================================================================

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

  # ============================================================================
  # Miscellaneous
  # ============================================================================

  # Is the event free of charge?
  #
  def free_of_charge?
    self.price_per_seat.zero?
  end

  # Does the event have uncounted (effectively, unrestricted) seating?
  #
  def unrestricted_seating?
    self.number_of_seats.zero?
  end

  # An at-the-instant estimate; returns +nil+ if seat count is unlimited. Never
  # returns less than zero otherwise.
  #
  def provisional_seats_remaining
    if self.unrestricted_seating?
      return nil
    else
      @provisional_seats_remaining ||= begin
        orders = Order.inflight.where(event: self)
        [0, self.number_of_seats - orders.sum(:number_of_seats)].max()
      end
    end
  end

  # An at-the-instant count based on reserved or paid orders only and will allow
  # a negative return value if an event ends up oversubscribed (e.g. because the
  # event was edited after orders had been placed). Returns +nil+ if seat count
  # is unlimited.
  #
  def confirmed_seats_remaining
    if self.unrestricted_seating?
      return nil
    else
      @confirmed_seats_remaining ||= begin
        orders = Order.confirmed.where(event: self)
        self.number_of_seats - orders.sum(:number_of_seats)
      end
    end
  end

  # ============================================================================
  # Utility functions
  # ============================================================================

  def human_state
    EventState.new(self.state).human_name
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Main definition
  # ============================================================================

  aasm(:state, namespace: 'state') do
    state :presales, initial: true
    state :reserver_purchases
    state :public_purchases
    state :archived
    state :cancelled

    event :start_reserver_purchases, after_commit: :notify_reservers do
      transitions from: :presales, to: :reserver_purchases, guard: :has_reservers?
    end

    event :start_public_purchases, after_commit: :cancel_reservations_and_notify_reservers do
      transitions from: [:presales, :reserver_purchases], to: :public_purchases
    end

    event :archive do
      transitions from: [:presales, :reserver_purchases, :public_purchases], to: :archived, guard: :has_concluded?
    end

    event :cancel, after_commit: :update_orders_for_cancellation do
      transitions from: [:presales, :reserver_purchases, :public_purchases], to: :cancelled
    end
  end

  def valid_events
    self.aasm(:state).events
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Guards
  # ============================================================================

  def has_reservers?
    self.orders.enum_state_reserved.any?
  end

  def has_concluded?
    self.ends_at <= Time.current
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': After-commit handlers
  # ============================================================================

  # Notify reservers that they can now make purchases via their magic link and
  # that once public sales start, it becomes a free-for-all.
  #
  def notify_reservers
    self.orders.enum_state_reserved.where.not(amount_owed: 0).each do |order|
      EventMailer.event_state_reserver_purchases_email(self).deliver_later()
    end
  end

  # Notify reservers that sales are now open to the public, so they need to
  # confirm their booking via payment ASAP or risk losing the seat.
  #
  # If there seems to be an error with notification, the order state change is
  # rolled back and an alert is sent out via Sentry.
  #
  def cancel_reservations_and_notify_reservers
    self.orders.enum_state_reserved.where.not(amount_owed: 0).each do |order|
      ActiveRecord::Base.transaction do
        order.update!(state: Order.states[:new])
        EventMailer.event_state_public_purchases_email(self).deliver()
      rescue => e
        Sentry.capture_exception(e)
        raise ActiveRecord::Rollback
      end
    end
  end

  # The event has been cancelled. Run order updates for appropriate states and
  # let the order model take care of notification e-mails.
  #
  def update_orders_for_cancellation

    # People who've paid get refunded.
    #
    self.orders.enum_state_paid.each do |order|
      ActiveRecord::Base.transaction do
        order.refund_state!
      rescue => e
        Sentry.capture_exception(e)
        raise ActiveRecord::Rollback
      end
    end

    # People with reservations have those reservations cancelled.
    #
    self.orders.enum_state_reserved.each do |order|
      ActiveRecord::Base.transaction do
        order.cancel_state!
      rescue => e
        Sentry.capture_exception(e)
        raise ActiveRecord::Rollback
      end
    end

    # New orders get set to a cancelled state too, but without a notification
    # e-mail since the order was never confirmed.
    #
    self.orders.enum_state_new.each do |order|
      begin
        order.update!(state: Order.states[:cancelled])
      rescue => e
        Sentry.capture_exception(e)
      end
    end
  end
end
