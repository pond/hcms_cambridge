# A redirection fallback which assumes attempts to fetch an unrecognised route
# will be either a page fetch where the path equates to slug,

class RedirectionsController < ApplicationController

  after_action :create_page_impression

  def show
    path = params[:path]

    if path == 'blog' || path == 'blog/'
      first_blog_page = Page.order(created_at: :asc).where(page_type: Page::PAGE_TYPE_BLOG).first

      if first_blog_page.nil?
        render_not_found()
      else
        redirect_to page_path(id: first_blog_page.slug), status: :moved_permanently
      end

    elsif path.start_with?('blog/')
      article_slug = path.split('/').last # Strip off e.g. dates - "https://.../blog/2025/08/04/some-slug-here"
      article      = Article.find_by_slug(article_slug)

      if article.nil?
        render_not_found()
      else
        redirect_to page_article_path(page_id: article.page.slug, id: article.slug), status: :moved_permanently
      end

    else
      probable_page_slug = path
      page               = Page.find_by_slug(probable_page_slug)

      if page.nil?
        render_not_found()
      else
        redirect_to page_path(id: page.slug), status: :moved_permanently
      end
    end
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    def render_not_found
      respond_to do |format|
        format.html { render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false }
        format.any  { head :not_found }
      end
    end

    # Called indiscriminately on after-action. Helps us analyse any missing
    # pages that hit the redirections controller but result in 404.
    #
    def create_page_impression
      PageImpression.create!(
        path:       request.path,
        referrer:   request.referrer,
        controller: controller_name,
        action:     action_name,
        params:     params.to_unsafe_hash.except('controller', 'action'),
        status:     response.status
      )
    end

end
