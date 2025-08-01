module PagesHelper
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
    link_text = if page.is_blog_type?
      if page.displayed_revision.published?
        if page.displayed_revision.current?
          'Edit blog page'
        else
          'Edit blog page, ignoring current draft'
        end
      elsif page.displayed_revision.current?
        'Continue editing blog page draft'
      else
        'Edit using this blog page revision'
      end
    else
      if page.displayed_revision.published?
        if page.displayed_revision.current?
          'Edit'
        else
          'Edit page, ignoring current draft'
        end
      elsif page.displayed_revision.current?
        'Continue editing draft'
      else
        'Edit using this revision'
      end
    end

    revision_id = params[:revision]
    revision_id = nil if revision_id&.to_i == page.current_revision.id

    return link_to(link_text, edit_admin_page_path(page, revision: revision_id))
  end
end
