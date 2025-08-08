class Admin::SessionsController < ::Devise::SessionsController
  layout 'admin'

  before_action :authenticate_admin_user! # (via Devise)
  skip_after_action :record_page_impression

  # Sleep a little to reduce brute force attack throughput, along with a bigger
  # sleep for bad credentials. Randomisation to thwart timing attack attempts.
  #
  def create
    sleep(0.5 + rand()) unless Rails.env.test?

    # The 'ensure' catches Warden bailing out early because of bad credentials
    # when we call 'super'.
    #
    begin
      super
    ensure
      unless admin_user_signed_in? || Rails.env.test?
        sleep(3.5 + rand())
      end
    end
  end
end
