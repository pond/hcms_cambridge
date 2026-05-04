class AddSupportedPaymentMethodsToEncounterOrder < ActiveRecord::Migration[8.1]
  def change
    create_enum :supported_payment_methods, EncounterOrder::SUPPORTED_PAYMENT_METHODS

    add_column(
      :encounter_orders,
      :supported_payment_methods,
      :enum,
      enum_type: :supported_payment_methods,
      array:     true,
      null:      false,
      default:   []
    )

    add_column(
      :encounter_orders,
      :supported_payment_method_other_details,
      :text
    )
  end
end
