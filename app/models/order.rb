class Order < ApplicationRecord
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
end
