module EventsHelper
  def evtshelp_edit_link_for(event, params)
    link_text = if event.displayed_revision.published?
      if event.displayed_revision.current?
        'Edit event'
      else
        'Edit event, ignoring current draft'
      end
    elsif event.displayed_revision.current?
      'Continue editing event draft'
    else
      'Edit using this event revision'
    end

    revision_id = params[:revision]
    revision_id = nil if revision_id&.to_i == event.current_revision.id

    return link_to(link_text, edit_admin_page_event_path(event.page, event, revision: revision_id))
  end

  def evtshelp_datetime(event)
    formatted_start = apphelp_human_time(event.starts_at)
    formatted_end   = apphelp_human_time(event.ends_at, time_only: (event.starts_at.to_date == event.ends_at.to_date))

    "#{formatted_start} until #{formatted_end}"
  end

  # Render the per-seat event price as a formatted string, with currency symbol.
  #
  def evtshelp_price(event)
    apphelp_money(
      event.price_per_seat,
      currency:       event.currency,
      free_of_charge: event.free_of_charge?
    )
  end

  # Render the location with a map link.
  #
  def evtshelp_location(event)
    link = link_to('map', "https://www.google.com/maps/search/?#{{api: 1, query: event.location}.to_query}", target: '_blank')
    text = h(event.location)

    "#{text} (#{link})".html_safe()
  end

  def evtshelp_booking_action_title(event)
    if event.state_presales?
      "Reserve seats"
    elsif event.state_reserver_purchases?
      "Pay for reservation"
    elsif event.state_public_purchases?
      if event.number_of_seats == 1 # Assume a bespoke one-off event entry
        "Pay for event"
      else
        "Book seats"
      end
    else
      nil
    end
  end

  def evntshelp_booking_button(event)
    return nil if event.free_of_charge? # NOTE EARLY EXIT

    if controller_name == 'waitlists'
      link_to(
        'Join waitlist',
        new_event_waitlist_path(event_id: event.slug),
        class: 'bold_button'
      )
    elsif event.provisional_seats_remaining > 0
      link_to(
        evtshelp_booking_action_title(event),
        new_page_event_order_path(page_id: event.page.slug, event_id: event.slug),
        class: 'bold_button'
      )
    elsif event.number_of_seats > 1
      link_to('Sold out', '#', class: 'bold_button disabled')
    else
      ""
    end
  end

  def evtshelp_admin_orders_link(event)
    link = link_to('Orders', admin_page_event_orders_path(event.page.slug, event.slug))
    confirmed_seat_count = event.confirmed_orders.sum(&:number_of_seats)

    if confirmed_seat_count > 0
      link = link.concat(" (#{confirmed_seat_count})")
    end

    link
  end

  def evtshelp_seat_state_glyph(event)
    if event.state_archived? || event.unrestricted_seating?
      ''
    elsif event.confirmed_seats_remaining < 0
      '⚠️'
    elsif event.confirmed_seats_remaining.zero?
      '✅'
    elsif event.confirmed_seats_remaining == event.number_of_seats
      '🟠'
    else
      '👤'
    end
  end

  def evtshelp_reply_link(order, link_text: nil)
    if order.email.blank?
      'Unknown'
    else
      link_text ||= order.email
      subject = if order.event&.title.present?
        if order.state_paid?
          "Your booking for \"#{order.event.title}\""
        else
          "Your reservation for \"#{order.event.title}\""
        end
      else
        if order.state_paid?
          "Your #{Hcms.config.site_name} booking"
        else
          "Your #{Hcms.config.site_name} reservation"
        end
      end

      mail_to(order.email, link_text, subject: subject)
    end
  end
end
