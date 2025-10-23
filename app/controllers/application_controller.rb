class ApplicationController < ActionController::Base

  public

    # Prevent CSRF attacks by raising an exception.
    protect_from_forgery with: :exception

    # Ad-hoc page visit counting.
    after_action :record_page_impression

    # The Rails Redactor integration assumes Devise is in a default
    # route location, but it isn't; so we need some aliases.
    alias :current_user :current_admin_user
    alias :user_signed_in? :admin_user_signed_in?
    alias :user_session :admin_user_session
    helper_method :current_user
    helper_method :user_signed_in?
    helper_method :user_session

    def redactor3_authenticate_user!
      authenticate_admin_user! # (via Devise)
    end

    def redactor3_current_user
      current_admin_user() # (via Devise)
    end

  private

    def record_page_impression
      return unless request.get? && response.successful?
      return if     request.xhr? || response.redirect?

      return if user_signed_in? # Don't record admin user (site owner) meanderings!

      browser = Browser.new(request.user_agent, accept_language: request.env['HTTP_ACCEPT_LANGUAGE'].presence)
      return if browser.bot?

      PageImpression.create!(
        path:       request.path,
        referrer:   request.referrer,
        controller: controller_name,
        action:     action_name,
        params:     params.to_unsafe_hash.except('controller', 'action'),
        status:     response.status
      )

      # Or record to Sentry via e.g.:
      #
      # Sentry.capture_message(
      #   "Page visit: #{request.path}",
      #   level: :info,
      #   extra: {
      #     controller: controller_name,
      #     action: action_name,
      #   },
      #   tags: {
      #     page: "#{controller_name}##{action_name}",
      #     path: request.path
      #   }
      # )
    end

end
