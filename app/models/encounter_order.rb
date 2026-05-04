# Represents a booking for an Encounter. These tend to be quite bespoke, unlike
# orders for Events. Whereas Event defines its own start and end date-time, an
# Encounter is booked for a customer-specified date-time so that information is
# held here, rather than in the parent Encounter.
#
# Prices are tax-inclusive if the parent Encounter is also tax-inclusive, else
# tax-exclusive. This can only really work in any meaningful way if there is a
# configured "tax_number", "tax_name" and "tax_rate" in 'Hcms.config'.
#
class EncounterOrder < ApplicationRecord
  class RefundError < StandardError; end

  include AASM

  has_secure_token()

  belongs_to :encounter
  has_one :stripe_payment, as: :payable, required: false, dependent: :destroy
  has_many :encounter_order_items, dependent: :destroy # (these are optional)

  accepts_nested_attributes_for(
    :encounter_order_items,
    allow_destroy: true,
    reject_if:     :all_blank
  )

  after_initialize :set_default_payment_methods!, unless: :persisted?
  before_save      :clean_default_payment_methods!

  # Uses the site name first letters capitalised plus "EI-" - e.g. for a site
  # name of "Some web site", the prefix would be "SWSEI-".
  #
  # "Our" invoices are usually only shown for non-Stripe payments, since Stripe
  # can give a 'true' invoice from the actual direct payment otherwise.
  #
  INVOICE_NUMBER_PREFIX = "#{Hcms.config.site_name.split(' ').map(&:first).join().upcase()}EI-"

  # Used for form submissions as a transient value only
  #
  attr_accessor :starts_at_kind

  STARTS_AT_KIND_OPEN_ENDED = 'open_ended'
  STARTS_AT_KIND_FIXED_DATE = 'fixed_date'

  # ============================================================================
  # Attribute overrides
  # ============================================================================

  def encounter=(encounter)
    super

    if self.new_record? and encounter.present?
      self.frozen_price_per_seat = self.encounter.price_per_seat
      self.frozen_price_physical = self.encounter.price_physical

      # Note use of "?" method which is overridden in Encounter, to makes sure
      # that required sales tax information is present.
      #
      self.frozen_price_on_application = self.encounter.price_on_application?
    end
  end

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

  # NB: This is also backed by a PostgreSQL array of an enum, so changes
  # require corresponding migrations. Enum originally created by
  # "20260504020644_add_payment_options_to_encounter_order.rb".
  #
  SUPPORTED_PAYMENT_METHOD_STRIPE = 'stripe'
  SUPPORTED_PAYMENT_METHOD_OTHER  = 'other'
  SUPPORTED_PAYMENT_METHODS       = [
    SUPPORTED_PAYMENT_METHOD_STRIPE,
    SUPPORTED_PAYMENT_METHOD_OTHER,
  ]

  validate do
    methods = self.supported_payment_methods.compact_blank
    invalid = methods - SUPPORTED_PAYMENT_METHODS

    if invalid.any?
      errors.add(:supported_payment_methods, "contains unsupported method(s) #{invalid.to_sentence}")
    elsif methods.none?
      errors.add(:supported_payment_methods, "must include at least one option")
    elsif self.includes_other_payment_method_option? && self.supported_payment_method_other_details.blank?
      errors.add(:supported_payment_method_other_details, :blank)
    end
  end

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

  # The 'inflight' scope gives a couple of days for people who've requested an
  # encounter to deal with payment before we start getting nervous about how
  # long it's been since the encounter order was created.
  #
  INFLIGHT_WINDOW = 3.days
  scope :inflight, -> {
    confirmed.or(where(state: self.states[:new], updated_at: INFLIGHT_WINDOW.ago..))
  }

  # Related to the above, stale encounter orders are in a "new" state and
  # haven't been touched in several days. Might need to get in touch with the
  # customer and check that everything's OK.
  #
  STALE_WINDOW = 7.days
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
      greater_than: 0,
      message:      'must be a positive whole number'
    }
  )

  # See similar validation in the Order model for rationale.
  #
  validate do
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
      stale_window = STALE_WINDOW

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

  # TODO: FIX ME? Invoice pages are accessed via tokens, so on that basis they
  #       cannot ever expire. Is there a better design?
  #
  def token_expires_at
    Time.now + 1.year
  end

  def open_ended?
    self.starts_at.blank?
  end

  def customer_self_service_possible?
    self.customer_can_pay_for_booking?
  end

  def customer_can_pay_for_booking?
    self.state_new? || self.state_payment_failed?
  end

  def admin_can_make_amendments?
    self.valid_events.any? && ! self.state_paid?
  end

  def price_agreed_by_application?
    self.frozen_price_on_application
  end

  def all_prices_exclude_sales_tax?
    self.price_agreed_by_application?
  end

  def theoretical_amount_owed_without_discounts
    if self.price_agreed_by_application?
      0
    else
      amount  = self.frozen_price_per_seat * self.number_of_seats
      amount += self.frozen_price_physical.to_i if self.has_physical
      amount
    end
  end

  def includes_discount?
    ! self.price_agreed_by_application? && (
      self.amount_owed < self.theoretical_amount_owed_without_discounts()
    )
  end

  # If the encounter prices exclude tax, then #amount_owed is tax-exclusive and
  # this function returns the amount *plus* tax (half-up rounding). Otherwise,
  # it just returns the same as #amount_owed.
  #
  # As with #amount_owed, return value is in smallest integer currency units.
  #
  def amount_owed_plus_tax
    if self.all_prices_exclude_sales_tax?
      tax_rate_decimal     = (BigDecimal(Hcms.config.tax_rate) / 100) + 1
      amount_owed_incl_tax = (self.amount_owed * tax_rate_decimal).round(0, BigDecimal::ROUND_HALF_UP)

      return amount_owed_incl_tax.to_i
    else
      return self.amount_owed
    end
  end

  # If the encounter prices exclude tax, then #amount_owed is tax-exclusive and
  # this function returns the amount of tax that must be added to get a total.
  # Otherwise, provided a tax rate is configured, it'll estimate the amount of
  # #amount_owed which already includes sale tax; and failing that, returns 0.
  #
  # As with #amount_owed, return value is in smallest integer currency units.
  #
  def amount_of_tax_owed
    if Hcms.config.tax_rate.present?
      tax_rate_decimal = (BigDecimal(Hcms.config.tax_rate) / 100) + 1

      return (
        if self.all_prices_exclude_sales_tax?
          amount_owed_incl_tax = (self.amount_owed * tax_rate_decimal).round(0, BigDecimal::ROUND_HALF_UP)
          tax_amount_excluded  = amount_owed_incl_tax - self.amount_owed
          tax_amount_excluded.to_i
        else
          amount_owed_excl_tax = (self.amount_owed / tax_rate_decimal).round(0, BigDecimal::ROUND_HALF_UP)
          tax_amount_included  = self.amount_owed - amount_owed_excl_tax
          tax_amount_included.to_i
        end
      )
    end

    return 0
  end

  def decorated_supported_payment_methods
    self.supported_payment_methods.map do |method|
      SupportedPaymentMethod.new(method)
    end
  end

  def includes_other_payment_method_option?
    self.supported_payment_methods.include?(SUPPORTED_PAYMENT_METHOD_OTHER)
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
      after_commit: :notify_is_refunded,
      guard:        :refund_state_makes_sense?
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

  def refund_state_makes_sense?
    self.amount_owed.present? && self.amount_owed > 0
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
        raise(
          RefundError,
          "Stripe refund error - state #{stripe_refund.status.inspect} for ID #{stripe_refund.id.inspect}"
        )
      end
    end
  end

  def notify_is_refunded
    if self.amount_owed > 0
      EncounterOrderMailer.encounter_order_state_refunded_email(self).deliver_later()
    end
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called via 'after_initialize' for new records only.
    #
    def set_default_payment_methods!
      if self.supported_payment_methods.empty?
        if self.frozen_price_on_application
          self.supported_payment_methods = [SUPPORTED_PAYMENT_METHOD_OTHER]
        else
          self.supported_payment_methods = SUPPORTED_PAYMENT_METHODS - [SUPPORTED_PAYMENT_METHOD_OTHER]
        end
      end
    end

    # Called via 'before_save' to strip any blank entries from the payment
    # methods array - Rails form submission data for "no checkboxes selected"
    # can lead to these.
    #
    def clean_default_payment_methods!
      self.supported_payment_methods.compact_blank!
    end

end
