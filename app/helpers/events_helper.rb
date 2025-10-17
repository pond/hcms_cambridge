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
    if Rails.application.config.uk_org_pond_hcms.currency.blank?
      '&ndash;'.html_safe()
    elsif event.price_per_seat.zero?
      'Free'
    else
      parsed_amount = Money.from_cents(
        event.price_per_seat,
        Rails.application.config.uk_org_pond_hcms.currency
      )
      parsed_amount.format()
    end
  end
end
