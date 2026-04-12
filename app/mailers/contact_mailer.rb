# This is currently used by "contact_form"-type pages only.
#
# The hosting Page or sufficiently compatible Page-like object should be defined
# in "@pagelike".
#
class ContactMailer < ApplicationMailer
  def contact_email(params)
    @pagelike = params.pagelike
    @name     = params.name
    @email    = params.email
    @phone    = params.phone
    @menu     = params.menu_selection
    @message  = params.message

    mail(
      to:      Hcms.config.contact_email,
      from:    Hcms.config.contact_email,
      subject: "[#{Hcms.config.site_name}] \"#{@pagelike.title}\" - message"
    )
  end
end
