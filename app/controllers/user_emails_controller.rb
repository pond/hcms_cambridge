class UserEmailsController < ApplicationController
  layout 'pages'

  before_filter do
    @page = OpenStruct.new
    @page.title = 'Contact'
  end

  def create
    is_booking = params.has_key?( 'date' ) && params.has_key?( 'time' )
    form_kind  = is_booking ? 'booking' : 'message'

    success = begin
      verify_recaptcha( {} )
    rescue
      false
    end

    # IMPORTANT! DO NOT put externally sourced data into @message, as it
    # rendered raw on the page (we want to add HTML to it sometimes).

    unless success
      @page.title = "Couldn't send #{ form_kind }"
      @message = "Sorry! The reCaptcha challenge wasn't happy with the response. Please try again or contact us by phone for assistance."
      return
    end

    unless params[ 'email' ].present? || params[ 'phone' ].present?
      @page.title = "Couldn't send #{ form_kind }"
      @message = "Sorry, you must provide at least an e-mail address or phone number so we can get back to you with a response."
      unless request.env['HTTP_REFERER'].empty?
        @message << ' ' << view_context.link_to( 'Please try again', request.env['HTTP_REFERER'] ) << '.'
      end
      return
    end

    if is_booking
      BookingMailer.booking_email( params ).deliver()
    else
      ContactMailer.contact_email( params ).deliver()
    end

    @message = "Your #{ form_kind } has been sent. We'll get back to you as soon as we can."
  end
end
