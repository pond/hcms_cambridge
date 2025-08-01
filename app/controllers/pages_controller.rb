class PagesController < ApplicationController

  layout 'pages'

  def show
    page_id = params[:id]

    if page_id.nil?
      if Page.none?
        redirect_to admin_pages_path() and return
      else
        page_id = Page.home.id
      end
    end

    if user_signed_in?
      redirect_to admin_page_path(id: page_id) and return
    else
      @page = Page.find_by_id_or_slug!(page_id)
    end
  end
end
