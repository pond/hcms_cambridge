class Admin::AdminMailer < ApplicationMailer
  def problematic_order_email(order)
    @order = order                || Order.new
    @email = order.email.presence || 'unknown@test.com'

    @admin_url = if order.event.present?
      if order.event.page.present?
        admin_page_event_orders_url(
          page_id:  order.event.page.slug,
          event_id: order.event.slug
        )
      else
        admin_page_events_url(
          page_id: order.event.page.slug,
        )
      end
    else
      admin_pages_url()
    end

    mail(
      to:      Hcms.config.contact_email,
      from:    @email,
      subject: "[#{Hcms.config.site_name}] PROBLEMATIC ORDER ALERT"
    )
  end
end
