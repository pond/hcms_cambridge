class TimeZoneHelp
  def self.in_configured_time_zone(datetime)
    time_zone    = Rails.application.config.time_zone # (see 'config/application.rb')
    current_year = Date.current.year                  # (uses above time zone - see https://api.rubyonrails.org/classes/Date.html#method-c-current)
    local_time   = datetime.in_time_zone(time_zone)
    formatter    = current_year == local_time.year ? :short_no_year : :short

    I18n.l(local_time, format: formatter)
  end
end
