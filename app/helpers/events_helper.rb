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
end
