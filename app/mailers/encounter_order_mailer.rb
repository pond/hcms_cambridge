class EncounterOrderMailer < ApplicationMailer
  helper :application, :encounter_orders, :encounters

  def encounter_order_state_paid_email(encounter_order)
    @encounter_order = encounter_order

    mail(
      to:      @encounter_order.email,
      from:    Hcms.config.orders_email,
      subject: "Booking confirmed for \"#{@encounter_order.encounter.title}\""
    )
  end

  def encounter_order_state_payment_failed_email(encounter_order)
    @encounter_order = encounter_order

    mail(
      to:      @encounter_order.email,
      from:    Hcms.config.orders_email,
      subject: "Payment failure for \"#{@encounter_order.encounter.title}\""
    )
  end

  # Note that for encounters, cancellations are only ever at the user's behest.
  #
  def encounter_order_state_cancelled_email(encounter_order)
    @encounter_order = encounter_order

    mail(
      to:      @encounter_order.email,
      from:    Hcms.config.orders_email,
      subject: "Confirmation of cancellation for \"#{@encounter_order.encounter.title}\""
    )
  end

  # Note that for encounters, refunds are only ever at the user's behest.
  #
  def encounter_order_state_refunded_email(encounter_order)
    @encounter_order = encounter_order

    mail(
      to:      @encounter_order.email,
      from:    Hcms.config.orders_email,
      subject: "Confirmation of refund for \"#{@encounter_order.encounter.title}\""
    )
  end
end
