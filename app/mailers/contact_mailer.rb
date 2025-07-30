class ContactMailer < ApplicationMailer
  def contact_email( params )
    @name    = params.name
    @email   = params.email
    @phone   = params.phone
    @menu    = params.menu_selection
    @message = params.message

    mail(
      to:      Rails.application.config.uk_org_pond_hcms.contact_email,
      from:    @email,
      subject: "#{Rails.application.config.uk_org_pond_hcms.site_name} web site general enquiry"
    )
  end
end
