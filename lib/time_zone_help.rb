class TimeZoneHelp
  def self.in_configured_time_zone(datetime)
    time_zone    = Rails.application.config.uk_org_pond_hcms.time_zone || 'London'
    current_year = Time.now.in_time_zone(time_zone).year
    local_time   = datetime.in_time_zone(time_zone)
    formatter    = current_year == local_time.year ? :short_no_year : :short

    I18n.l(local_time, format: formatter)
  end
end
