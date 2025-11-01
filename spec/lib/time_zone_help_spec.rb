require "spec_helper.rb"

RSpec.describe TimeZoneHelp do
  around :each do | example |
    old_tz = Rails.application.config.time_zone
    example.run
  ensure
    Rails.application.config.time_zone = old_tz
  end

  context "not this year" do
    it "obeys configured time zone and includes the year" do
      Rails.application.config.time_zone = "Brisbane" # UTC+10, no DST
      base_datetime = Time.parse("#{Date.current.year + 2}-01-01T16:00Z")
      expect(TimeZoneHelp.in_configured_time_zone(base_datetime)).to eql("Jan 2 2027 (Saturday), 2:00am")

      Rails.application.config.time_zone = "Hawaii" # UTC-10, no DST
      base_datetime = Time.parse("#{Date.current.year + 2}-01-01T04:30Z")
      expect(TimeZoneHelp.in_configured_time_zone(base_datetime)).to eql("Dec 31 2026 (Thursday), 6:30pm")
    end
  end

  context "in this year" do
    it "obeys configured time zone and omits the year" do
      Rails.application.config.time_zone = "Brisbane" # UTC+10, no DST
      base_datetime = Time.parse("#{Date.current.year + 2}-01-01T16:00Z")

      travel_to(base_datetime) do
        expect(TimeZoneHelp.in_configured_time_zone(base_datetime)).to eql("Jan 2 (Saturday), 2:00am")
      end

      Rails.application.config.time_zone = "Hawaii" # UTC-10, no DST
      base_datetime = Time.parse("#{Date.current.year + 2}-01-01T04:30Z")

      travel_to(base_datetime - 1.year) do
        expect(TimeZoneHelp.in_configured_time_zone(base_datetime)).to eql("Dec 31 (Thursday), 6:30pm")
      end
    end
  end
end
