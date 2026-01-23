module EncountersHelper
  def encshelp_edit_link_for(encounter, params)
    link_text = if encounter.displayed_revision.published?
      if encounter.displayed_revision.current?
        'Edit encounter'
      else
        'Edit encounter, ignoring current draft'
      end
    elsif encounter.displayed_revision.current?
      'Continue editing encounter draft'
    else
      'Edit using this encounter revision'
    end

    revision_id = params[:revision]
    revision_id = nil if revision_id.to_i == encounter.current_revision.id

    return link_to(link_text, edit_admin_encounter_path(encounter, revision: revision_id))
  end

  def encshelp_datetime(encounter)
    if encounter.starts_at.nil?
      'Open-ended'
    else
      apphelp_human_time(encounter.starts_at)
    end
  end

  # Render the per-seat encounter price as a formatted string, with currency symbol.
  #
  def encshelp_price(encounter, for_physical_aspect: false)
    if for_physical_aspect
      apphelp_money(
        encounter.price_physical,
        currency:       encounter.currency,
        free_of_charge: encounter.physical_aspect_free_of_charge?
      )
    else
      apphelp_money(
        encounter.price_per_seat,
        currency:       encounter.currency,
        free_of_charge: encounter.free_of_charge?
      )
    end
  end

  # Render the location with a map link.
  #
  def encshelp_location(encounter)
    link = link_to('map', "https://www.google.com/maps/search/?#{{api: 1, query: encounter.location}.to_query}", target: '_blank')
    text = h(encounter.location)

    "#{text} (#{link})".html_safe()
  end

  def encshelp_booking_button(encounter)
    return nil if encounter.free_of_charge? # NOTE EARLY EXIT

    link_to(
      "Set up encounter",
      new_admin_encounter_encounter_order_path(encounter_id: encounter.slug),
      class: 'bold_button'
    )
  end

  def encshelp_admin_orders_link(encounter)
    link_to('Orders', admin_encounter_encounter_orders_path(encounter.slug))
  end

  def encshelp_reply_link(encounter_order, link_text: nil)
    if encounter_order.email.blank?
      'Unknown'
    else
      link_text ||= encounter_order.email
      subject = if encounter_order.encounter&.title.present?
        "Your booking for \"#{encounter_order.encounter.title}\""
      else
        "Your #{Hcms.config.site_name} booking"
      end

      mail_to(encounter_order.email, link_text, subject: subject)
    end
  end
end
