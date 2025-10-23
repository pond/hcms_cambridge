class Order < ApplicationRecord

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  enum(
    :state,
    {
      new:            'new',
      successful:     'successful',
      payment_failed: 'payment_failed',
      cancelled:      'cancelled',
      refunded:       'refunded',
    },
    prefix:  true,
    default: :new
  )

  STATES = self.states.keys

  default_scope -> { order(created_at: :desc) }
  scope :inflight, -> { where(state: [self.states[:new], self.states[:successful]]) }

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
end
