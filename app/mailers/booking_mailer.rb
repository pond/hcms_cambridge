class BookingMailer < ApplicationMailer
  def booking_email(params)
    @page  = params.page
    @name  = params.name
    @email = params.email
    @phone = params.phone
    @time  = params.time
    @date  = params.date
    @menu  = params.menu_selection
    @notes = params.notes

    mail(
      to:      Hcms.config.booking_email,
      from:    Hcms.config.booking_email,
      subject: "[#{Hcms.config.site_name}] \"#{@page.title}\" - booking enquiry"
    )
  end
end
