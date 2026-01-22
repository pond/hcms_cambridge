class EncounterOrder < ApplicationRecord
  include AASM

  has_secure_token()

  belongs_to :encounter
  has_one :stripe_payment, required: false, dependent: :destroy

  # Uses the site name first letters capitalised plus "I-" - e.g. for a site
  # name of "Some web site", the prefix would be "SWSI-".
  #
  # "Our" invoices are usually only shown for non-Stripe payments, since Stripe
  # can give a 'true' invoice from the actual direct payment otherwise.
  #
  INVOICE_NUMBER_PREFIX = "#{Hcms.config.site_name.split(' ').map(&:first).join().upcase()}I-"

  # ============================================================================
  # Enumerations (see also any AASM state machine definition(s) later)
  # ============================================================================

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010035603_add_orders.rb".
  #
  # (And yes, that's an *order* state - EncounterOrder uses the same states).
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
      reserved:       'reserved', # (not used for EncounterOrders)
      paid:           'paid',
      payment_failed: 'payment_failed',
      cancelled:      'cancelled',
      refunded:       'refunded',
    },
    prefix:  'enum_state',
    default: :new,
  )

  STATES = self.states.keys

  # These states mean that an associated encounter shouldn't be deleted, since
  # users will want to refer to it (e.g. via invoices or in-flight orders).
  # Some states may be reversible, e.g. a reservation can be cancelled. See
  # also IRREVOCABLE_REFUSE_ENCOUNTER_DELETION_STATES.
  #
  REFUSE_ENCOUNTER_DELETION_STATES = [
    self.states[:reserved],
    self.states[:payment_failed],
    self.states[:paid],
    self.states[:refunded],
  ]

  # These states are related to REFUSE_ENCOUNTER_DELETION_STATES but represent
  # orders which "lock" the encounter for invoicing purposes.
  #
  IRREVOCABLE_REFUSE_ENCOUNTER_DELETION_STATES = [
    self.states[:paid],
    self.states[:refunded],
  ]

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

  validates_presence_of :address, if: -> (order) { order.encounter.price_per_seat > 100000 }

  # Note that the state machine enum is validated automatically.

  validates :email,                         format:       { with: URI::MailTo::EMAIL_REGEXP }
  validates :number_of_seats, :amount_owed, numericality: { only_integer: true, message: 'must be a whole number' }

  validate :number_of_seats do |order|
    if order.encounter.present? && order.encounter.number_of_seats > 0
      encounter        = order.encounter
      other_orders = encounter.orders.inflight.where.not(id: self.id)
      remaining    = [0, encounter.number_of_seats - other_orders.sum(:number_of_seats)].max()

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

  def human_invoice_number
    "#{INVOICE_NUMBER_PREFIX}#{self.invoice_number}"
  end

  def token_expires_at
    Time.now + 1.year # TODO: FIX ME! - invoice pages are accessed from here.
  end

  def customer_self_service_possible?
    self.customer_can_pay_for_booking?
  end

  def customer_can_pay_for_booking?
    self.state_new? || self.state_payment_failed?
  end

  def includes_discount?
    self.amount_owed < self.encounter.price_per_seat * self.number_of_seats
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Main definition
  # ============================================================================

  aasm(:state, namespace: 'state') do
    state :new, initial: true
    state :reserved # (not used for EncounterOrders)
    state :payment_failed
    state :paid
    state :refunded
    state :cancelled

    event :pay, after_commit: :notify_is_paid do
      transitions from: [:new, :payment_failed], to: :paid, guard: :paid_state_makes_sense?
    end

    # At the time of writing this comment, this state is hypothetical and is
    # not relevant to off-site (Stripe-hosted) payments, since Stripe handles
    # payments itself and if they fail, they "fail within" Stripe's UI. We get
    # a success-or-cancel redirection URI only.
    #
    # This is kept here in case of future need.
    #
    event :payment_failed, after_commit: :notify_payment_failed do
      transitions from: [:new], to: :payment_failed
    end

    event :cancel, after_commit: :notify_is_cancelled do
      transitions from: [:new, :payment_failed], to: :cancelled
    end

    event(
      :refund,
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
    self.encounter.present? && self.customer_can_pay_for_booking?
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Callback handlers
  # ============================================================================

  def notify_is_paid
    EncounterOrderMailer.encounter_order_state_paid_email(self).deliver_later()
    Admin::AdminMailer.encounter_order_paid(self).deliver_later()
  end

  def notify_payment_failed
    EncounterOrderMailer.encounter_order_state_payment_failed_email(self).deliver_later()
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
      EncounterOrderMailer.encounter_order_state_refunded_email(self).deliver_later()
    end
  end
end
