# This is currently used by "booking_form"-type pages that allow ad hoc booking
# enquiries, and via showing an Encounter, for encounter-specific enquiries.
#
# The Page or sufficiently compatible Page-like object such as an Encounter
# should be defined in "@pagelike".
#
class BookingMailer < ApplicationMailer
  def booking_email(params)
    @pagelike = params.pagelike
    @name     = params.name
    @email    = params.email
    @phone    = params.phone
    @time     = params.time
    @date     = params.date
    @menu     = params.menu_selection
    @notes    = params.notes

    mail(
      to:      Hcms.config.booking_email,
      from:    Hcms.config.booking_email,
      subject: "[#{Hcms.config.site_name}] \"#{@pagelike.title}\" - booking enquiry"
    )
  end
end
