class Admin::SessionsController < ::Devise::SessionsController
  layout "admin"

  # Via Devise
  before_action :authenticate_admin_user!
end
