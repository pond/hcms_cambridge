module EncounterOrdersHelper
  def encordshelp_datetime(encounter_order)
    if encounter_order.starts_at.nil?
      'Open-ended'
    else
      apphelp_human_time(encounter_order.starts_at)
    end
  end

  # Generates a "manage encounter" URL based on order ID and token.
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
        To manage your encounter, use this link:

          #{encordshelp_magic_link(encounter_order)}

        This expires on #{apphelp_human_time(encounter_order.token_expires_at)}.
      TEXT

      return text
    else
      html = <<~HTML.html_safe() # WARNING - must only HTML-safe text inside
        <p>
          To manage your encounter, use this link:
        </p>

        <ul>
          <li>
            <strong>
              #{link_to('Manage encounter', encordshelp_magic_link(encounter_order))}
            </strong>
            (expires on #{apphelp_human_time(encounter_order.token_expires_at)})
          </li>
        </ul>
      HTML

      return html
    end
  end
end
