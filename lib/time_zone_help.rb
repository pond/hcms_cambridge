class TimeZoneHelp
  def self.in_configured_time_zone(datetime, time_only: false, date_only: false, invoice: false)
    time_zone    = Rails.application.config.time_zone # (see 'config/application.rb')
    current_year = Date.current.year                  # (uses above time zone - see https://api.rubyonrails.org/classes/Date.html#method-c-current)
    local_time   = datetime.in_time_zone(time_zone)
    formatter    = if invoice
      :invoice_date
    elsif date_only
      :date_only
    elsif time_only
      :time_only
    elsif current_year == local_time.year
       :short_no_year
    else
      :short
    end

    I18n.l(local_time, format: formatter)
  end
end
