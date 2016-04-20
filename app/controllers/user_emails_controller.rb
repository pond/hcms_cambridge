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

    unless success
      @page.title = "Couldn't send #{ form_kind }"
      @message = "Sorry! The reCaptcha challenge wasn't happy with the response. Please try again or contact us by phone for assistance."
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



# "name"=>"", "email"=>"", "phone"=>"", "notes"=>""
#
# "g-recaptcha-response"=>"03A...JHapw",
#
# bookings only
# "date"=>"", "time"=>""
#
# optional on anything
# "selection"=>{"selection"=>"Shared Tour (see above for rates)"}
