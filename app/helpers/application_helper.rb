module ApplicationHelper
  def apphelp_human_time(datetime)
    current_year = Time.now.in_time_zone('London').year
    local_time   = datetime.in_time_zone('London')
    formatter    = current_year == local_time.year ? :short_no_year : short

    l(local_time, format: formatter)
  end
end
