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

  def evtshelp_price(event)
    apphelp_money(
      event.price_per_seat,
      currency:       event.currency,
      free_of_charge: event.free_of_charge?
    )
  end

  def evtshelp_booking_action_title(event)
    if event.state_presales?
      "Reserve seats"
    elsif event.state_reservee_purchases?
      "Pay for reservation"
    elsif event.state_public_purchases?
      "Book seats"
    else
      nil
    end
  end

  def evntshelp_booking_button(event)
    return nil if event.free_of_charge? # NOTE EARLY EXIT

    if event.provisional_seats_remaining > 0
      link_to(
        evtshelp_booking_action_title(event),
        new_page_event_order_path(page_id: event.page.slug, event_id: event.slug),
        class: 'bold_button'
      )
    else
      link_to('Sold out', '#', class: 'bold_button disabled')
    end
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
      ''
    end
  end
end
