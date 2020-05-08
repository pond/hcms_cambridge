class Admin::ConvertToBlogController < ApplicationController

  layout 'admin'

  before_action :authenticate_admin_user! # Via Devise
  before_action :set_page

  public

    # GET /admin/pages/<page_id>/convert_to_blog/new
    def new
    end

    # POST /admin/pages/<page_id>/convert_to_blog/
    def create

      # if @page.save
      #   redirect_to [:admin, @page], notice: 'Page was successfully created.'
      # else
      #   render :new
      # end
    end

  private

    def set_page
      @page = Page.find_by_id_or_slug!( params[ :page_id ] )
    end

end
