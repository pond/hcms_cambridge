class PagesController < ApplicationController

  layout 'pages'

  IS_INTEGER = /\A\d+\z/

  def show
    if params[:id].nil?
      @page = Page.home()
    else
      @page = Page.find_by_id_or_slug!( params[ :id ] )
    end
  end
end
