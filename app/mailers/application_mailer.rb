class ApplicationMailer < ActionMailer::Base
  default from: Hcms.config.contact_email
  layout 'mailer'
end
