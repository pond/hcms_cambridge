# Show a page based on title, rather than ID.

class ByTitlesController < ApplicationController
  layout 'pages'

  def show
    raise ActiveRecord::RecordNotFound if params[ :id ].nil?

    human = params[ :id ].titleize

    @page = Page.where( "lower(title) = ?", human.downcase ).first
    raise ActiveRecord::RecordNotFound if @page.nil?

    render 'pages/show'
  end
end
