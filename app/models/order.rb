class Order < ApplicationRecord

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
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
    prefix:  true,
    default: :new
  )

  STATES = self.states.keys

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

  belongs_to :event

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
end
