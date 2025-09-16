# A redirection fallback which assumes attempts to fetch an unrecognised route
# will be either a page fetch where the path equates to slug,

class RedirectionsController < ApplicationController

  after_action :create_page_impression

  # Map a path or path prefix to the slug of a blog page. Within that, any
  # remaining path segments are checked against article slugs, to redirect if
  # possible to a specific article, else at least the overall blog.
  #
  BLOG_MAPPINGS = {} # Populated by #show calling #populate_constants!

  # Other customised redirections. These match the full path, or path prefix.
  #
  PAGE_MAPPINGS = {} # Populated by #show calling #populate_constants!

  # Don't create a page impression record for these path extensions. They're
  # typically from bot/fuzzer junk and by inspection we can see that they have
  # no value in indicating a missed redirection that should be recorded.
  #
  IGNORE_EXTENSIONS = Set.new(%w{
    .env
    .ini
    .key
    .php
    .php7
    .php8
    .py
  })

  # Used internally by the no-page-impression ignore system for configurable
  # mappings in 'config.yml', mapping config sections to Ruby string methods.
  #
  STATS_IGNORE_METHODS = {
    'match_exactly'  => :eql?,
    'starts_with'    => :start_with?,
    'found_anywhere' => :include?
  }

  def show
    self.populate_constants! if BLOG_MAPPINGS.blank?

    clean_request_path = self.get_clean_path()
    redirection_path   = self.get_redirection_path(clean_request_path)

    if redirection_path.nil?
      render_not_found()
    else
      redirect_to(redirection_path, status: :moved_permanently)
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

    # Lazy-populate the mapping constants via configuration data.
    #
    def populate_constants!
      Rails.application.config.uk_org_pond_hcms.blog_mappings&.each do | path, blog_page_slug |
        BLOG_MAPPINGS[path] = Page.find_by_slug(blog_page_slug) # Note, might be "nil"
      end

      Rails.application.config.uk_org_pond_hcms.page_mappings&.each do | path, other_page_slug |
        PAGE_MAPPINGS[path] = Page.find_by_slug(other_page_slug) # Note, might be "nil"
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

    # Based on (clean) request path (see #get_clean_path), return a redirection
    # path that best matches it, or "nil" if no match is found.
    #
    def get_redirection_path(requested_path)

      # NOTE EARLY EXITS throughout this whole method.
      #
      # First, bail out if matching immediate 404 conditions.
      #
      return nil if File.extname(requested_path).present? || requested_path.start_with?('.')

      # Otherwise, chop up the path so "foo/" or "foo" give a single-item array
      # of "foo", say, or "foo/bar/baz" yields those three items.
      #
      requested_path_segments = requested_path.split('/')

      # Try blog pages next, for a possible match directly to a specific article.
      #
      BLOG_MAPPINGS.each do | blog_path, mapped_blog_page |
        next if mapped_blog_page.nil? || requested_path_segments.first != blog_path

        if requested_path_segments.size == 1 # No additional segments -> go to container
          return page_path(id: mapped_blog_page.slug)
        else # Any "date/month/year" style mid-path (or not), terminating in slug -> try article
          possible_article_slug = requested_path_segments.last
          matching_article      = mapped_blog_page.articles.find_by_slug(possible_article_slug)

          if matching_article.nil?
            return page_path(id: mapped_blog_page.slug)
          else
            return page_article_path(page_id: mapped_blog_page.slug, id: matching_article.slug)
          end
        end
      end

      # Now try the custom mappings for specific individual pages.
      #
      PAGE_MAPPINGS.each do | page_path, mapped_other_page |
        if mapped_other_page.present? && requested_path_segments.first == page_path
          return page_path(id: mapped_other_page.slug)
        end
      end

      # Otherwise, see if there's an actual as-is slug match.
      #
      possible_slug = requested_path_segments.last
      matching_page = Page.find_by_slug(possible_slug)

      if matching_page.nil?
        matching_article = Article.find_by_slug(possible_slug)

        if matching_article.nil?
          return nil
        else
          return page_article_path(page_id: matching_article.page.slug, id: matching_article.slug)
        end
      else
        return page_path(id: matching_page.slug)
      end
    end

    # Render *without* a page impression record?
    #
    def no_page_impression?
      path      = self.get_clean_path().downcase
      extension = File.extname(path)

      # Referrers are almost always blank for bot spam, but they might also be
      # blank for e.g. links in apps like Instagram or from e-mail clients. A
      # trade-off between bot noise and real user interactions must be made.
      #
      early_exit = (
        # request.referrer.blank?             || # If enabled, look for "RESTORE THIS" in "redirections_spec.rb" and uncomment the test
        IGNORE_EXTENSIONS.include?(extension)
      )

      return true if early_exit

      Rails.application.config.uk_org_pond_hcms.statistics_ignore.each do |section, list|
        matcher = STATS_IGNORE_METHODS[section]

        list.each do | item |
          return true if path.send(matcher, item)
        end
      end

      return false
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
