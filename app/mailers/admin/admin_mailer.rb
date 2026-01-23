class Admin::AdminMailer < ApplicationMailer
  helper :events

  def order_reserved(order)
    @order = order

    mail(
      to:      Hcms.config.orders_email,
      from:    Hcms.config.orders_email,
      subject: "[#{Hcms.config.site_name}] New reservation from #{order.name}"
    )
  end

  def order_paid(order)
    @order = order

    mail(
      to:      Hcms.config.orders_email,
      from:    Hcms.config.orders_email,
      subject: "[#{Hcms.config.site_name}] New paid booking from #{order.name}"
    )
  end

  def order_cancelled(order)
    @order = order

    mail(
      to:      Hcms.config.orders_email,
      from:    Hcms.config.orders_email,
      subject: "[#{Hcms.config.site_name}] Cancellation from #{order.name}"
    )
  end

  def problematic_order_email(order)
    @order = order || Order.new

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
      to:      Hcms.config.orders_email,
      from:    Hcms.config.orders_email,
      subject: "[#{Hcms.config.site_name}] PROBLEMATIC ORDER ALERT"
    )
  end

  def problematic_encounter_order_email(encounter_order)
    @encounter_order = encounter_order || EncounterOrder.new

    @admin_url = if encounter_order.encounter.present?
      admin_encounter_encounter_orders_url(
        encounter_id: encounter_order.encounter.slug,
      )
    else
      admin_encounters_url()
    end

    mail(
      to:      Hcms.config.orders_email,
      from:    Hcms.config.orders_email,
      subject: "[#{Hcms.config.site_name}] PROBLEMATIC ENCOUNTER ORDER ALERT"
    )
  end
end
