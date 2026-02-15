class EncounterOrder < ApplicationRecord
  include AASM

  has_secure_token()

  belongs_to :encounter
  has_one :stripe_payment, as: :payable, required: false, dependent: :destroy

  # Uses the site name first letters capitalised plus "I-" - e.g. for a site
  # name of "Some web site", the prefix would be "SWSI-".
  #
  # "Our" invoices are usually only shown for non-Stripe payments, since Stripe
  # can give a 'true' invoice from the actual direct payment otherwise.
  #
  INVOICE_NUMBER_PREFIX = "#{Hcms.config.site_name.split(' ').map(&:first).join().upcase()}I-"

  # Used for form submissions as a transient value only
  #
  attr_accessor :starts_at_kind

  STARTS_AT_KIND_OPEN_ENDED = 'open_ended'
  STARTS_AT_KIND_FIXED_DATE = 'fixed_date'

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
    self.states[:reserved], # (not used for EncounterOrders)
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
          self.states[:reserved      ], # (not used for EncounterOrders)
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

  # The 'inflight' scope gives a couple of days for people who've requested an
  # encounter to deal with payment before we start getting nervous about how
  # long it's been since the encounter order was created.
  #
  INFLIGHT_WINDOW = 2.days
  scope :inflight, -> {
    confirmed.or(where(state: self.states[:new], updated_at: INFLIGHT_WINDOW.ago..))
  }

  # Related to the above, stale encounter orders are in a "new" state and
  # haven't been touched in several days. Might need to get in touch with the
  # customer and check that everything's OK.
  #
  STALE_WINDOW = 5.days
  scope :stale, -> { where(state: self.states[:new], updated_at: ..STALE_WINDOW.ago) }

  # ============================================================================
  # Validations
  # ============================================================================

  # Note that the state machine enum is validated automatically.

  validates_presence_of %i{
    name
    email
    number_of_seats
    amount_owed
  }

  validates_presence_of(
    :address,
    if: -> (encounter_order) {
      Hcms.config.tax_threshold.is_a?(Integer) &&
      encounter_order.amount_owed.is_a?(Integer) &&
      encounter_order.amount_owed >= Hcms.config.tax_threshold
    }
  )

  validates(
    :starts_at,
    allow_blank: true,
    comparison:  {
      greater_than: -> { Time.current },
      message:      'must be in the future'
    }
  )

  validates(
    :email,
    format:  {
      with: URI::MailTo::EMAIL_REGEXP,
      message: 'must be a valid e-mail address'
    }
  )

  validates(
    :number_of_seats,
    :amount_owed,
    numericality: { only_integer: true, message: 'must be a whole number' }
  )

  # See similar validation in the Order model for rationale.
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
    standard_amount_owed  = self.encounter.price_per_seat * self.number_of_seats
    standard_amount_owed += self.encounter.price_physical.to_i if self.has_physical

    self.amount_owed < standard_amount_owed
  end

  def open_ended?
    self.starts_at.blank?
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

    event :reserve, guard: -> { false }

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
    EncounterOrder.aasm(:state).events.filter do |event|
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

  def notify_is_cancelled
    EncounterOrderMailer.encounter_order_state_cancelled_email(self).deliver_later()

    unless self.state_previously_was == self.class.states[:new]
      Admin::AdminMailer.encounter_order_cancelled(self).deliver_later()
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
      EncounterOrderMailer.encounter_order_state_refunded_email(self).deliver_later()
    end
  end
end
