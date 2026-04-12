class UserEmailsController < ApplicationController

  # Renders only if there's a form error; uses a dynamic layout per-render.

  before_action do
    @pagelike = if params.key?(:page_id)
      Page.find(params[:page_id])
    else
      Encounter.find(params[:encounter_id])
    end
  end

  def create
    form_kind   = @pagelike.is_booking_form? ? 'booking enquiry' : 'message'
    form_class  = @pagelike.form_class
    safe_params = params
      .require(form_class.model_name.param_key)
      .permit(form_class.permitted_params)

    @form_model          = form_class.new(safe_params)
    @form_model.pagelike = @pagelike

    unless @form_model.valid?
      flash[:alert] = "There were problems with the information you gave"
      render_pagelike(@pagelike)
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
      flash[:alert] = "Sorry, the anti-robots checker wasn't happy... Please try again or contact us by phone or social medial for assistance."
      render_pagelike(@pagelike)
      return
    end

    if @pagelike.is_booking_form?
      BookingMailer.booking_email(@form_model).deliver()
    else
      ContactMailer.contact_email(@form_model).deliver()
    end

    redirect_to(root_path, notice: "Your #{ form_kind } has been sent. We'll get back to you as soon as we can.")
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    def render_pagelike(pagelike)
      ivar_name                 = pagelike.model_name.singular
      layout_name               = pagelike.model_name.plural
      rendered_if_showing_again = "#{layout_name}/show"

      # A for-pages layout expects "@page", a for-encounters layout expects
      # "@encounter".
      #
      instance_variable_set("@#{ivar_name}", pagelike)

      render rendered_if_showing_again, layout: layout_name
    end
end
