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
      subject: "Refund confirmation for \"#{@order.event.title}\""
    )
  end
end
