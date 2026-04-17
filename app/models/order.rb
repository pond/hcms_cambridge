class Order < ApplicationRecord
  include AASM

  has_secure_token()

  belongs_to :event
  has_one :stripe_payment, as: :payable, required: false, dependent: :destroy

  # Uses the site name first letters capitalised plus "I-" - e.g. for a site
  # name of "Some web site", the prefix would be "SWSI-".
  #
  # "Our" invoices are usually only shown for non-Stripe payments, since Stripe
  # can give a 'true' invoice from the actual direct payment otherwise.
  #
  INVOICE_NUMBER_PREFIX = "#{Hcms.config.site_name.split(' ').map(&:first).join().upcase()}I-"

  # ============================================================================
  # Association ov
  # ============================================================================

  def event=(event)
    super

    if self.new_record? and event.present?
      self.frozen_price_per_seat = self.event.price_per_seat
    end
  end

  # ============================================================================
  # Enumerations (see also any AASM state machine definition(s) later)
  # ============================================================================

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010035603_add_orders.rb".
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
    default: :new,
  )

  STATES = self.states.keys

  # These states mean that an associated event shouldn't be deleted, since
  # users will want to refer to it (e.g. via invoices or in-flight orders).
  # Some states may be reversible, e.g. a reservation can be cancelled. See
  # also IRREVOCABLE_REFUSE_EVENT_DELETION_STATES.
  #
  REFUSE_EVENT_DELETION_STATES = [
    self.states[:reserved],
    self.states[:payment_failed],
    self.states[:paid],
    self.states[:refunded],
  ]

  # These states are related to REFUSE_EVENT_DELETION_STATES but represent
  # orders which "lock" the event for invoicing purposes.
  #
  IRREVOCABLE_REFUSE_EVENT_DELETION_STATES = [
    self.states[:paid],
    self.states[:refunded],
  ]

  # ============================================================================
  # Scopes
  # ============================================================================

  STATE_LIST_SQL = <<~SQL
    CASE state
      WHEN ? THEN 1
      WHEN ? THEN 2
      WHEN ? THEN 3
      WHEN ? THEN 4
      WHEN ? THEN 5
      WHEN ? THEN 6
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
          self.states[:paid          ],
          self.states[:reserved      ],
          self.states[:cancelled     ],
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

  validates_presence_of :address, if: -> (order) {
    Hcms.config.tax_threshold.is_a?(Integer) &&
    order.amount_owed.is_a?(Integer) &&
    order.amount_owed >= Hcms.config.tax_threshold
  }

  # Note that the state machine enum is validated automatically.

  validates(
    :email,
    format: {
      with:    URI::MailTo::EMAIL_REGEXP,
      message: 'must be a valid e-mail address'
    }
  )

  # A defensive validation.
  #
  # Back-end processing takes human-entered, formatted money amounts and turns
  # it into integer smallest currency units, so this should never happen...
  #
  validates(
    :amount_owed,
    numericality: { only_integer: true }
  )

  validates(
    :number_of_seats,
    numericality: {
      only_integer: true,
      message:      'must be a positive whole number'
    }
  )

  validate :number_of_seats do
    if (
      self.number_of_seats.present?  &&
      self.number_of_seats > 0       &&
      self.event.present?            &&
      self.event.number_of_seats > 0
    )
      event        = self.event
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
  validate :phone_number do
    if self.phone_number.present?
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
    if self.state_new? && self.updated_at.present?
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

  def human_invoice_number
    "#{INVOICE_NUMBER_PREFIX}#{self.invoice_number}"
  end

  def token_expires_at
    Time.now + 1.year # TODO: FIX ME! - invoice pages are accessed from here.
    # .event.ends_at + 1.day
  end

  def theoretical_amount_owed_without_discounts
    self.frozen_price_per_seat * self.number_of_seats
  end

  def customer_self_service_possible?
    self.customer_can_pay_for_reservation? ||
    self.customer_can_pay_for_booking?
  end

  # Reservations mean you've essentially expressed an interest in an event which
  # was accepting such things ("presales" state) previously, and now things have
  # changed so that this reservation can be solidified into a booking.
  #
  def customer_can_pay_for_reservation?
    ! self.event.has_started? &&
    (self.state_reserved? || self.state_payment_failed?) &&
    (
      self.event.state_reserver_purchases? ||
      self.event.state_public_purchases?
    )
  end

  # You can pay for an event booking if you either could pay for a prior
  # reservation, *or* if this is a new order for an event that's accepting
  # public purchases.
  #
  def customer_can_pay_for_booking?
    self.customer_can_pay_for_reservation? ||
    (
      ! self.event.has_started? &&
      (self.state_new? || self.state_payment_failed?) &&
      self.event.state_public_purchases?
    )
  end

  def includes_discount?
    self.amount_owed < self.theoretical_amount_owed_without_discounts()
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

    event(
      :refund,
      guard:        :outside_no_refunds_window?,
      before:       :process_refund,
      after_commit: :notify_is_refunded
    ) do
      transitions from: :paid, to: :refunded
    end

    event(
      :force_refund,
      before:       :process_refund,
      after_commit: :notify_is_refunded
    ) do
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

  # Is this order *outside* the no-refunds window - that is, should a refund be
  # allowed under normal circumstances?
  #
  # * Always allowed if the event was cancelled
  # * Always allowed if the configured window period is zero
  # * Otherwise the event cannot start within the configured number of days
  #   from now.
  #
  def outside_no_refunds_window?
    self.event.state_cancelled? ||
    Hcms.config.no_refunds_window.zero? ||
    Time.current < (self.event.starts_at - Hcms.config.no_refunds_window.days)
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Callback handlers
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

    unless self.event.state_cancelled? || self.state_previously_was == self.class.states[:new]
      Admin::AdminMailer.order_cancelled(self).deliver_later()
    end
  end

  def process_refund
    if self.stripe_payment.present?
      stripe_refund = Stripe::Refund.create(payment_intent: self.stripe_payment.stripe_payment_intent)

      if stripe_refund.status == 'succeeded'
        self.stripe_payment.destroy!
      else
        raise "Stripe refund error - state #{stripe_refund.status.inspect} for ID #{stripe_refund.id.inspect}"
      end
    end
  end

  def notify_is_refunded
    if self.amount_owed > 0
      OrderMailer.order_state_refunded_email(self).deliver_later()
    elsif self.event.state_cancelled?
      OrderMailer.order_state_cancelled_email(self).deliver_later()
    end
  end
end
