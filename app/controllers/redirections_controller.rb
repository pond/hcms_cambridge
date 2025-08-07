# A redirection fallback which assumes attempts to fetch an unrecognised route
# will be either a page fetch where the path equates to slug,

class RedirectionsController < ApplicationController
  def show
    path = params[:path]

    if path.start_with?('blog/')
      article_slug = path.split('/').last # Strip off e.g. dates - "https://.../blog/2025/08/04/some-slug-here"
      article      = Article.find_by_slug(article_slug)

      if article.nil?
        render_not_found()
      else
        redirect_to page_article_path(page_id: article.page.slug, id: article.slug)
      end
    else
      probable_page_slug = path
      page               = Page.find_by_slug(probable_page_slug)

      if article.nil?
        render_not_found()
      else
        redirect_to page_path(id: page.slug)
      end
    end
  end

  private

    def render_not_found
      respond_to do |format|
        format.html { render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false }
        format.any  { head :not_found }
      end
    end
end
