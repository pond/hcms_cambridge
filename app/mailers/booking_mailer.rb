class BookingMailer < ApplicationMailer
  default to: Rails.application.config.uk_org_pond_hcms.booking_email

  def booking_email( params )
    @name  = params.name
    @email = params.email
    @phone = params.phone
    @time  = params.time
    @date  = params.date
    @menu  = params.menu_selection
    @notes = params.notes

    mail(
      to:      Rails.application.config.uk_org_pond_hcms.booking_email,
      from:    @email,
      subject: "#{Rails.application.config.uk_org_pond_hcms.site_name} web site booking request"
    )
  end
end
