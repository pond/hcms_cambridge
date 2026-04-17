# Optional line item manually added to Encounter Orders; they show in invoices.
# Typically used for highly bespoke encounter setups, e.g. for corporate events.
#
class EncounterOrderItem < ApplicationRecord
  belongs_to :encounter_order

  validates_presence_of %i{
    description
    amount_owed
  }

  # Partially just a defensive validation.
  #
  # Back-end processing takes human-entered, formatted money amounts and turns
  # it into integer smallest currency units, so the "greater than zero" part of
  # this validation is the only thing ever expected to happen.
  #
  validates(
    :amount_owed,
    numericality: {
      only_integer: true,
      greater_than: 0,
      message:      'must be a positive number'
    }
  )
end
