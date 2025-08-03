class Admin::SessionsController < ::Devise::SessionsController
  layout "admin"

  # Via Devise
  before_action :authenticate_admin_user!

  # By sleeping a few seconds before any sign-in attempt, we delay humans
  # wanting to sign in, but not very much; more importantly, we dramatically
  # reduce the throughput possible for brute force attacks on the page.
  #
  def create
    sleep(4.5 + rand()) unless Rails.env.test?
    super
  end
end
