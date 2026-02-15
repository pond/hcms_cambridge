class ContactMailer < ApplicationMailer
  def contact_email(params)
    @page    = params.page
    @name    = params.name
    @email   = params.email
    @phone   = params.phone
    @menu    = params.menu_selection
    @message = params.message

    mail(
      to:      Hcms.config.contact_email,
      from:    Hcms.config.contact_email,
      subject: "[#{Hcms.config.site_name}] \"#{@page.title}\" - message"
    )
  end
end
