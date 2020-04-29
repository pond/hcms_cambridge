# Show a page based on title, rather than ID. This is outdated now that slugs
# are supported properly, but kept around in case of historical bookmarks etc.
#
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
