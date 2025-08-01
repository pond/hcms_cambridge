class PagesController < ApplicationController

  layout 'pages'

  def show
    if user_signed_in?
      redirect_to admin_page_path(id: params[:id] || Page.home().id)
    else
      if params[:id].nil?
        @page = Page.home()
      else
        @page = Page.find_by_id_or_slug!( params[ :id ] )
      end

      @form_model = @page&.form_class&.new
    end
  end
end
