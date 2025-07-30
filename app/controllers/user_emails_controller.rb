class UserEmailsController < ApplicationController
  layout 'pages'

  before_action do
    @page = Page.find(params[:page_id])
  end

  def create
    form_kind   = @page.is_booking_form? ? 'booking enquiry' : 'message'
    form_class  = @page.form_class
    safe_params = params
      .require(form_class.model_name.param_key)
      .permit(form_class.permitted_params)

    @form_model = form_class.new(safe_params)

    unless @form_model.valid?
      flash[:alert] = "There were problems with the information you gave"

      render 'pages/show'
      return
    end

    success = begin
      verify_recaptcha(action: 'contact')
    rescue
      false
    end

    # IMPORTANT! DO NOT put externally sourced data into @message, as it
    # rendered raw on the page (we want to add HTML to it sometimes).

    unless success
      flash[:alert] = "Sorry! The reCaptcha challenge wasn't happy with the response. Please try again or contact us by phone for assistance."

      render 'pages/show'
      return
    end

    @page = OpenStruct.new
    @page.title = "#{form_kind.capitalize} sent"

    if @page.is_booking_form?
      BookingMailer.booking_email(@form_model).deliver()
    else
      ContactMailer.contact_email(@form_model).deliver()
    end

    @message = "Your #{ form_kind } has been sent. We'll get back to you as soon as we can."
  end
end
