class PagesController < ApplicationController

  layout 'pages'

  def show
    if params[:id].nil?
      @page = Page.home()
    else
      @page = Page.find_by_id_or_slug!( params[ :id ] )
    end

    @form_model = @page&.form_class&.new
  end
end
