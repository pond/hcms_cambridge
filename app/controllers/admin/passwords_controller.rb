class Admin::PasswordsController < ::Devise::PasswordsController
  layout 'admin'

  before_action :authenticate_admin_user! # (via Devise)
end
