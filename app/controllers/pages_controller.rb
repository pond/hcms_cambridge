class PagesController < ApplicationController

  layout 'pages'

  def show
    if params[:id].nil?
      @page = Page.home()
    else
      @page = Page.find_by_id_or_slug!( params[ :id ] )
    end

    form_class  = @page&.form_class
    @form_model = form_class.new unless form_class.nil?
  end
end
