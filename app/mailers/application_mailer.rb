class ApplicationMailer < ActionMailer::Base
  include Roadie::Rails::Automatic

  layout 'mailer'
  default from: Hcms.config.contact_email
end
