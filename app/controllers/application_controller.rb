class ApplicationController < ActionController::Base

  public

    # Prevent CSRF attacks by raising an exception.
    protect_from_forgery :with => :exception

    # The Rails Redactor integration assumes Devise is in a default
    # route location, but it isn't; so we need some aliases.
    alias :current_user :current_admin_user
    alias :user_signed_in? :admin_user_signed_in?
    alias :user_session :admin_user_session
    helper_method :current_user
    helper_method :user_signed_in?
    helper_method :user_session

    def redactor3_authenticate_user!
      authenticate_admin_user! # devise before_action
    end

    def redactor3_current_user
      current_admin_user # devise user helper
    end

end
