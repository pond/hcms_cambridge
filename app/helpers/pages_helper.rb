module PagesHelper
  LINK_TEXTS = {
    page: {
      edit:                'Edit',
      edit_ignore_draft:   'Edit page, ignoring current draft',
      edit_continue_draft: 'Continue editing draft',
      edit_old_revision:   'Edit using this revision',
    },
    blog: {
      edit:                'Edit blog page',
      edit_ignore_draft:   'Edit blog page, ignoring current draft',
      edit_continue_draft: 'Continue editing blog page draft',
      edit_old_revision:   'Edit using this blog page revision',
    },
    events: {
      edit:                'Edit events page',
      edit_ignore_draft:   'Edit events page, ignoring current draft',
      edit_continue_draft: 'Continue editing events page draft',
      edit_old_revision:   'Edit using this events page revision',
    },
  }

  def pageshelp_form_page_selection_list(f, page)
    text  = page.form_selection_list_contents.strip
    items = text.split("\n")
    items.map! do | item |
      item.strip!
      OpenStruct.new(form_value: item, human_text: item)
    end

    f.collection_select(:menu_selection, items, :form_value, :human_text)
  end

  def pageshelp_edit_link_for(page, params)
    key = if page.is_blog_type?
      :blog
    elsif page.is_events_type?
      :events
    else
      :page
    end

    link_text = if page.displayed_revision.published?
      if page.displayed_revision.current?
        LINK_TEXTS[key][:edit]
      else
        LINK_TEXTS[key][:edit_ignore_draft]
      end
    elsif page.displayed_revision.current?
      LINK_TEXTS[key][:edit_continue_draft]
    else
      LINK_TEXTS[key][:edit_old_revision]
    end

    revision_id = params[:revision]
    revision_id = nil if revision_id&.to_i == page.current_revision.id

    return link_to(link_text, edit_admin_page_path(page, revision: revision_id))
  end
end
