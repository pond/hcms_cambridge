module ArticlesHelper
  def artshelp_edit_link_for(article, params)
    link_text = if article.displayed_revision.published?
      if article.displayed_revision.current?
        'Edit article'
      else
        'Edit article, ignoring current draft'
      end
    elsif article.displayed_revision.current?
      'Continue editing article draft'
    else
      'Edit using this article revision'
    end

    revision_id = params[:revision]
    revision_id = nil if revision_id&.to_i == article.current_revision.id

    return link_to(link_text, edit_admin_page_article_path(article.page, article, revision: revision_id))
  end
end
