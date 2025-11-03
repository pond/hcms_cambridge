class Order < ApplicationRecord
  include AASM

  has_secure_token()

  belongs_to :event
  has_one :stripe_payment, required: false, dependent: :destroy

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
  STALE_WINDOW = 2.days
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
    if order.event.present? && order.event.number_of_seats > 0
      event        = order.event
      other_orders = event.orders.inflight.where.not(id: self.id)
      remaining    = [0, event.number_of_seats - other_orders.sum(:number_of_seats)].max()

      if remaining < (self.number_of_seats || 0)
        self.errors.add(
          :number_of_seats,
          "requested is too high - only #{remaining} left"
        )
      end
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

  def token_expires_at
    self.event.ends_at + 1.day
  end

  def customer_self_service_possible?
    self.customer_can_pay_for_reservation? ||
    self.customer_can_pay_for_booking?
  end

  def customer_can_pay_for_reservation?
    ! self.event.has_started? &&
    (self.state_reserved? || self.state_payment_failed?) &&
    (
      self.event.state_reserver_purchases? ||
      self.event.state_public_purchases?
    )
  end

  def customer_can_pay_for_booking?
    self.customer_can_pay_for_reservation? ||
    (
      ! self.event.has_started? &&
      (self.state_new? || self.state_payment_failed?) &&
      self.event.state_public_purchases?
    )
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
      transitions from: [:new, :reserved, :payment_failed], to: :paid, guard: :paid_state_makes_sense?
    end

    # At the time of writing this comment, this state is hypothetical and is
    # not relevant to off-site (Stripe-hosted) payments, since Stripe handles
    # payments itself and if they fail, they "fail within" Stripe's UI. We get
    # a success-or-cancel redirection URI only.
    #
    # This is kept here in case of future need.
    #
    event :payment_failed, after_commit: :notify_payment_failed do
      transitions from: [:new, :reserved], to: :payment_failed
    end

    event :cancel, after_commit: :notify_is_cancelled do
      transitions from: [:new, :reserved, :payment_failed], to: :cancelled
    end

    event :refund, after_commit: :refund_and_notify_is_refunded, guard: :outside_no_refunds_window? do
      transitions from: :paid, to: :refunded
    end

    event :force_refund, after_commit: :refund_and_notify_is_refunded, guard: :inside_no_refunds_window? do
      transitions from: :paid, to: :refunded
    end
  end

  # The 'aasm(:state)' method on 'self' does not appear to take account of
  # guards, only transition conditions. The method here only returns events
  # the instance can *actually* use - at least, at the instant of calling.
  #
  def valid_events
    Order.aasm(:state).events.filter do |event|
      self.send("may_#{event.name}_state?")
    end
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Guards
  # ============================================================================

  # A "paid" state is entered immediately if amount-owed is zero, so that's not
  # the condition for a guard - only the event-vs-order states matter.
  #
  def paid_state_makes_sense? # (AASM guard)
    self.event.present? && (
      self.customer_can_pay_for_reservation? ||
      self.customer_can_pay_for_booking?
    )
  end

  def reservation_makes_sense? # (AASM guard)
    self.event.present? &&
    self.event.state_presales? &&
    ! self.event.has_started?
  end

  def outside_no_refunds_window?
    Hcms.config.no_refunds_window.zero? ||
    Time.current < (self.event.starts_at - Hcms.config.no_refunds_window.days)
  end

  def inside_no_refunds_window?
    ! self.outside_no_refunds_window?
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': After-commit handlers
  # ============================================================================

  def notify_is_reserved
    OrderMailer.order_state_reserved_email(self).deliver_later()
    Admin::AdminMailer.order_reserved(self).deliver_later()
  end

  def notify_is_paid
    OrderMailer.order_state_paid_email(self).deliver_later()
    Admin::AdminMailer.order_paid(self).deliver_later()
  end

  def notify_payment_failed
    OrderMailer.order_state_payment_failed_email(self).deliver_later()
  end

  def notify_is_cancelled
    OrderMailer.order_state_cancelled_email(self).deliver_later()
    unless self.state_previously_was == self.class.states[:new]
      Admin::AdminMailer.order_cancelled(self).deliver_later()
    end
  end

  def refund_and_notify_is_refunded
    if self.state_paid?
      raise "Refund goes here!"
    end
    OrderMailer.order_state_refunded_email(self).deliver_later()
  end
end
