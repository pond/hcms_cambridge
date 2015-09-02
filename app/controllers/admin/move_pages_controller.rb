# This is a dedicated controller which just edits [Admin::]Pages by
# calling the acts-as-list "move higher" or "move lower" methods.

class Admin::MovePagesController < ApplicationController

  # Via Devise
  before_action :authenticate_admin_user!

  def update
    admin_page = Admin::Page.find( params[ :id ] )

    if params.has_key?( :higher )
      admin_page.move_higher
    elsif params.has_key?( :lower )
      admin_page.move_lower
    end

    redirect_to admin_pages_path()
  end
end
