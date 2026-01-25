module EncounterOrdersHelper

  # Returns a formatted start date-time for the encounter order, allowing for
  # open-ended bookings.
  #
  def encordshelp_datetime(encounter_order)
    if encounter_order.starts_at.nil?
      'Open-ended'
    else
      apphelp_human_time(encounter_order.starts_at)
    end
  end

  # Returns a formatted due date for an invoice, allowing for open-ended
  # bookings. The invoice is deemed due within 7 days for those, else due
  # within 1 day of the encounter's booked start date.
  #
  def encordshelp_formatted_invoice_due_date(encounter_order)
    datetime = if @encounter_order.open_ended?
      @encounter_order.created_at + 7.days
    else
      @encounter_order.starts_at - 1.day
    end

    return apphelp_human_time(datetime, invoice: true)
  end

  # Generates a shareable "your encounter" URL based on encounter order token.
  #
  def encordshelp_share_link(encounter_order)
    return your_encounter_order_url(
      token: encounter_order.token,
    )
  end

  # Returns explanation text with a link to see details of the given encounter
  # order without any prices shown, in HTML or plain text. In each case, the
  # returned string terminates with a newline.
  #
  def encordshelp_share_link_markup(encounter_order, plain_text:)
    if plain_text
      text = <<~TEXT
        To share details with other people, send them this link:

          #{encordshelp_share_link(encounter_order)}
      TEXT

      return text
    else
      html = <<~HTML.html_safe() # WARNING - must only HTML-safe text inside
        <p>
          To share details with other people, send them this link:
        </p>

        <ul>
          <li>
            <strong>
              #{link_to('Your encounter', encordshelp_share_link(encounter_order))}
            </strong>
          </li>
        </ul>
      HTML

      return html
    end
  end

  # Generates a "manage encounter" URL based on encounter order ID and token.
  #
  def encordshelp_magic_link(encounter_order)
    return manage_encounter_order_url(
      encounter_order_id: encounter_order.id,
      token:              encounter_order.token,
    )
  end

  # Returns explanation text with a link to manage the given encounter order,
  # in HTML or plain text. In each case, the returned string terminates with a
  # newline.
  #
  def encordshelp_magic_link_markup(encounter_order, plain_text:)
    if plain_text
      text = <<~TEXT
        To manage your booking, use this link:

          #{encordshelp_magic_link(encounter_order)}

        This expires on #{apphelp_human_time(encounter_order.token_expires_at)}.
      TEXT

      return text
    else
      html = <<~HTML.html_safe() # WARNING - must only HTML-safe text inside
        <p>
          To manage your booking, use this link:
        </p>

        <ul>
          <li>
            <strong>
              #{link_to('Manage booking', encordshelp_magic_link(encounter_order))}
            </strong>
            (expires on #{apphelp_human_time(encounter_order.token_expires_at)})
          </li>
        </ul>
      HTML

      return html
    end
  end
end
