class Admin::PasswordsController < ::Devise::PasswordsController
  layout "admin"

  # Via Devise
  before_action :authenticate_admin_user!
end
