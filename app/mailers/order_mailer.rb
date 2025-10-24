class OrderMailer < ApplicationMailer
  def reservation_confirmed_email(params)
    @order = params.order

    mail(
      to:      @order.email,
      from:    Hcms.config.order_email,
      subject: "Reservation confirmed for \"#{@order.title}\""
    )
  end

  def booking_confirmed_email(params)
    @order = params.order

    mail(
      to:      @order.email,
      from:    Hcms.config.order_email,
      subject: "Booking confirmed for \"#{@order.title}\""
    )
  end
end
