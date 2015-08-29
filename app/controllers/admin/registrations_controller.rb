class Admin::RegistrationsController < ::Devise::RegistrationsController
  layout "admin"

  # Via Devise
  before_action :authenticate_admin_user!

  before_filter :check_if_admin_already_exists

  private

    def check_if_admin_already_exists
      if User.count > 0
        flash[ :alert ] = 'New sign-ups are currently not allowed'
        redirect_to new_admin_user_session_path()
      end
    end
end
