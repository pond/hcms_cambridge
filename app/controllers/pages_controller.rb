class PagesController < ApplicationController

  layout 'pages'

  def show
    if params[ :id ].nil?
      @page = Page.order( :created_at => :asc ).first
    else
      @page = Page.find( params[ :id ] )
    end
  end
end
