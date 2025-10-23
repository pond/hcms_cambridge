# This is a dedicated controller which just edits [Admin::]Pages by
# calling the acts-as-list "move higher" or "move lower" methods.

class Admin::MovePagesController < ApplicationController

  before_action :authenticate_admin_user! # (via Devise)

  def update
    page = Page.find( params[ :id ] )

    if params.has_key?( :higher )
      page.move_higher
    elsif params.has_key?( :lower )
      page.move_lower
    end

    redirect_to admin_pages_path()
  end
end
