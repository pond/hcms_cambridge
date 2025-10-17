class Order < ApplicationRecord
  ORDER_STATE_NEW            = "new"
  ORDER_STATE_SUCCESS        = "success"
  ORDER_STATE_PAYMENT_FAILED = "payment_failed"
  ORDER_STATE_CANCELLED      = "cancelled"
  ORDER_STATE_REFUNDED       = "refunded"

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010035603_add_orders.rb".
  #
  ORDER_STATES = [
    ORDER_STATE_NEW,
    ORDER_STATE_SUCCESS,
    ORDER_STATE_PAYMENT_FAILED,
    ORDER_STATE_CANCELLED,
    ORDER_STATE_REFUNDED,
  ]

  default_scope -> { order(created_at: :desc) }

  belongs_to :event

  validates_presence_of %i{
    name
    email_address
    number_of_seats
    amount_owed
    currency
    status
  }

  after_initialize(unless: :persisted?) do
    self.state = ORDER_STATE_NEW
  end
end
