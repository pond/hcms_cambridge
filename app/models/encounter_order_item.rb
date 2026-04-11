# Optional line item manually added to Encounter Orders; they show in invoices.
# Typically used for highly bespoke encounter setups, e.g. for corporate events.
#
class EncounterOrderItem < ApplicationRecord
  belongs_to :encounter_order

  validates_presence_of(
    :encounter_order,
    :description,
    :amount_owed
  )
end
