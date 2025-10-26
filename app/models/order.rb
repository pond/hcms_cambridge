class Order < ApplicationRecord
  include AASM

  belongs_to :event

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
      new:            'new',
      reserved:       'reserved',
      paid:           'paid',
      payment_failed: 'payment_failed',
      cancelled:      'cancelled',
      refunded:       'refunded',
    },
    prefix:  'enum_state',
    default: :new
  )

  STATES = self.states.keys

  # ============================================================================
  # Scopes
  # ============================================================================

  STATE_LIST_SQL = <<~SQL
    CASE state
      WHEN ? THEN 1
      WHEN ? THEN 4
      WHEN ? THEN 2
      WHEN ? THEN 3
      WHEN ? THEN 5
      WHEN ? THEN 5
      ELSE 100
    END ASC,
    created_at ASC
  SQL

  default_scope -> {
    order(
      Arel.sql(
        self.sanitize_sql_array([
          STATE_LIST_SQL,
          self.states[:payment_failed],
          self.states[:cancelled     ],
          self.states[:paid          ],
          self.states[:reserved      ],
          self.states[:refunded      ],
          self.states[:new           ],
        ])
      )
    )
  }

  scope :confirmed, -> {
    where(state: [self.states[:reserved], self.states[:paid]])
  }

  scope :problematic, -> {
    where(state: self.states[:payment_failed])
  }

  scope :miscellaneous, -> {
    where(state: [self.states[:new], self.states[:cancelled], self.states[:refunded]])
  }

  # The 'inflight' scope includes a few minutes on new-state orders for people
  # going through the checkout flow, to help avoid having seats snatched out
  # from under them in-flow; other people coming in to place later orders will
  # see a reduced availability while that time window applies.
  #
  INFLIGHT_WINDOW = 10.minutes
  scope :inflight, -> {
    confirmed.or(where(state: self.states[:new], updated_at: INFLIGHT_WINDOW.ago..))
  }

  # Related to the above, stale orders are in a "new" state and haven't been
  # touched in a few days. They're fair game for deletion.
  #
  STALE_WINDOW = 3.days
  scope :stale, -> { where(state: self.states[:new], updated_at: ..STALE_WINDOW.ago) }

  # ============================================================================
  # Validations
  # ============================================================================

  validates_presence_of %i{
    name
    email
    number_of_seats
    amount_owed
    state
  }

  validates :email,                         format:       { with: URI::MailTo::EMAIL_REGEXP }
  validates :number_of_seats, :amount_owed, numericality: { only_integer: true, message: 'must be a whole number' }
  validates :state,                         inclusion:    { in: STATES,         message: 'is not recognised'      }

  validate :number_of_seats do |order|
    if (
      order.event.present? &&
      order.event.number_of_seats > 0 &&
      order.event.provisional_seats_remaining < (self.number_of_seats || 0)
    )
      self.errors.add(
        :number_of_seats,
        "requested is too high - only #{order.event.provisional_seats_remaining} left"
      )
    end
  end

  # Validation also rewrites the number in international or national format.
  # The latter is friendly to humans, but does only have meaning in the context
  # of the globally configured country code. If that were to change, there
  # ideally would be a data migration to rewrite numbers to international so
  # that they still made sense. In practice, we're unlikely to care about
  # phone numbers on older orders and might even clear them out now and again
  # to avoid unnecessary accumulation of unwanted PII.
  #
  validate :phone_number do |order|
    if order.phone_number.present?
      parsed = Phonelib.parse(self.phone_number)
      if parsed.valid?
        if parsed.countries.include?(Hcms.config.country_code)
          self.phone_number = parsed.national
        else
          self.phone_number = parsed.international
        end
      else
        self.errors.add(
          :phone_number,
          'seems to be invalid - if it is an international number, please include the country code'
        )
      end
    end
  end

  # ============================================================================
  # Utility functions
  # ============================================================================

  def human_state
    state_for_i18n = self.state

    # See "en.yml", models.order_state
    #
    if self.state_new?
      if self.updated_at < INFLIGHT_WINDOW.ago
        if self.updated_at > STALE_WINDOW.ago
          state_for_i18n = 'getting_older'
        else
          state_for_i18n = 'stale'
        end
      end
    end

    OrderState.new(state_for_i18n).human_name
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Main definition
  # ============================================================================

  aasm(:state, namespace: 'state') do
    state :new, initial: true
    state :reserved
    state :payment_failed
    state :paid
    state :refunded
    state :cancelled

    event :reserve, after_commit: :notify_is_reserved do
      transitions from: :new, to: :reserved, guard: :reservation_makes_sense?
    end

    event :pay, after_commit: :notify_is_paid do
      transitions from: [:new, :reserved, :payment_failed], to: :paid, guard: :payment_makes_sense?
    end

    event :payment_failed, after_commit: :notify_payment_failed do
      transitions from: [:new, :reserved], to: :payment_failed
    end

    event :cancel, after_commit: :notify_is_cancelled do
      transitions from: [:new, :reserved, :payment_failed], to: :cancelled
    end

    event :refund, after_commit: :refund_and_notify_is_refunded do
      transitions from: :paid, to: :refunded
    end
  end

  def valid_events
    self.aasm(:state).events
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Guards
  # ============================================================================

  def payment_makes_sense? # (AASM guard)
    self.event&.free_of_charge? == false
  end

  def reservation_makes_sense? # (AASM guard)
    self.event&.state_presales? == true
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': After-commit handlers
  # ============================================================================

  def notify_is_reserved
    OrderMailer.order_state_reserved_email(self).deliver_later()
  end

  def notify_is_paid
    OrderMailer.order_state_paid_email(self).deliver_later()
  end

  def notify_payment_failed
    OrderMailer.order_state_payment_failed_email(self).deliver_later()
  end

  def notify_is_cancelled
    OrderMailer.order_state_cancelled_email(self).deliver_later()
  end

  def refund_and_notify_is_refunded
    if self.state_paid?
      raise "Refund goes here!"
    end
    OrderMailer.order_state_refunded_email(self).deliver_later()
  end
end
