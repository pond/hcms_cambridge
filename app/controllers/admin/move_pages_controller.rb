# This is a dedicated controller which just edits [Admin::]Pages by
# calling the acts-as-list "move higher" or "move lower" methods.

class Admin::MovePagesController < ApplicationController

  # Via Devise
  before_action :authenticate_admin_user!

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
