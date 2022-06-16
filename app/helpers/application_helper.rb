module ApplicationHelper
  def apphelp_destroy_confirm(thing)
    message = 'Are you sure? This cannot be undone!'

    if thing.is_a?(Page) && thing.is_blog_type? && thing.articles.any?
      message = "Are you sure? The page's blog articles will be deleted too. This cannot be undone!"
    end

    message
  end

  def apphelp_human_time(datetime)
    current_year = Time.now.in_time_zone('London').year
    local_time   = datetime.in_time_zone('London')
    formatter    = current_year == local_time.year ? :short_no_year : :short

    l(local_time, format: formatter)
  end
end
