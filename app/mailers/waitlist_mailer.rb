class WaitlistMailer < ApplicationMailer
  #helper :application, :orders, :events

  # Sent for Reserved orders when the event starts accepting public payments,
  # so the reservation is no longer guaranteed.
  #
  def join_waitlist_request_email(order)
    @order = order

    mail(
      to:      Hcms.config.orders_email,
      from:    Hcms.config.orders_email,
      subject: "[#{Hcms.config.site_name}] Request to join waitlist for \"#{@order.event.title}\""
    )
  end
end
