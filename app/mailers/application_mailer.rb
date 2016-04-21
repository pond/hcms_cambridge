class ApplicationMailer < ActionMailer::Base
  default :to => Rails.application.config.uk_org_pond_hcms_email
  layout 'mailer'
end
