class OrderMailer < ApplicationMailer
  helper :application, :orders, :events

  def order_state_reserved_email(order)
    @order = order

    mail(
      to:      @order.email,
      from:    Hcms.config.orders_email,
      subject: "Reservation confirmed for \"#{@order.event.title}\""
    )
  end

  def order_state_paid_email(order)
    @order = order

    mail(
      to:      @order.email,
      from:    Hcms.config.orders_email,
      subject: "Booking confirmed for \"#{@order.event.title}\""
    )
  end

  # Note that cancellations could be at the user's behest or because the event
  # itself got cancelled, so the subject line needs to allow for either.
  #
  def order_state_cancelled_email(order)
    @order = order

    mail(
      to:      @order.email,
      from:    Hcms.config.orders_email,
      subject: "Confirmation of cancellation for \"#{@order.event.title}\""
    )
  end

  def order_state_payment_failed_email(order)
    @order = order

    mail(
      to:      @order.email,
      from:    Hcms.config.orders_email,
      subject: "Payment failure for \"#{@order.event.title}\""
    )
  end

  # Note that refunds could be at the user's behest or because the event
  # itself got cancelled, so the subject line needs to allow for either.
  #
  def order_state_refunded_email(order)
    @order = order

    mail(
      to:      @order.email,
      from:    Hcms.config.orders_email,
      subject: "Confirmation of refund for \"#{@order.event.title}\""
    )
  end

  # Sent for Reserved orders when the event starts accepting reservation
  # confirmation payments.
  #
  def event_state_reserver_purchases_email(order)
    @order = order

    mail(
      to:      @order.email,
      from:    Hcms.config.orders_email,
      subject: "It's time to confirm your booking for \"#{@order.event.title}\""
    )
  end

  # Sent for Reserved orders when the event starts accepting public payments,
  # so the reservation is no longer guaranteed.
  #
  def event_state_public_purchases_email(order)
    @order = order

    mail(
      to:      @order.email,
      from:    Hcms.config.orders_email,
      subject: "General sales now available for \"#{@order.event.title}\""
    )
  end
end
