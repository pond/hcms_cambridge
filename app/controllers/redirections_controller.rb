# A redirection fallback which assumes attempts to fetch an unrecognised route
# will be either a page fetch where the path equates to slug,

class RedirectionsController < ApplicationController

  after_action :create_page_impression

  # Don't create a page impression record for these path extensions. They're
  # typically from bot/fuzzer junk and by inspection we can see that they have
  # no value in indicating a missed redirection that should be recorded.
  #
  IGNORE_EXTENSIONS = ['.php', '.py', '.key']

  # More specific redirections. These match the full path, or path prefix.
  #
  CUSTOM_MAPPINGS = {
    'whats-on'           => 'previous-events',
    'tastings-events'    => 'previous-events',
    'tastings-education' => 'private-tastings',
    'tastings-private'   => 'private-tastings',
    'tasting-enquiry'    => 'private-tastings',
  }

  def show
    path = self.get_clean_path()

    if File.extname(path).present? || path.start_with?('.')
      render_not_found()

    elsif path == 'blog' || path == 'blog/'
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

    elsif (mapped_page = custom_redirection_for(path))
      redirect_to page_path(id: mapped_page)

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

    # Pull a clean path from params - no ".htm" or ".html" extension. Other
    # extensions may be present, of course, depending on the request.
    #
    def get_clean_path
      @path ||= begin
        path = params[:path] || ''
        path.chomp!('.htm')
        path.chomp!('.html')
        path
      end
    end

    # Render *without* a page impression record?
    #
    def no_page_impression?
      path      = self.get_clean_path()
      extension = File.extname(path)

      IGNORE_EXTENSIONS.include?(extension) || path.start_with?('wp-') || path.start_with?('.')
    end

    # Returns a custom mapping for the given path, else +nil+.
    #
    def custom_redirection_for(path)
      CUSTOM_MAPPINGS.each do | match_path, mapped_page |
        match_path_slash = "#{match_path}/"

        if path == match_path || path == match_path_slash || path.start_with?(match_path_slash)
          return mapped_page
        end
      end

      nil
    end

    # Called indiscriminately on after-action. Helps us analyse any missing
    # pages that hit the redirections controller but result in 404.
    #
    def create_page_impression
      unless self.no_page_impression?
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

end
