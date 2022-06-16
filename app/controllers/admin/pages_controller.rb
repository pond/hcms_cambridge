class Admin::PagesController < ApplicationController

  layout :determine_layout
  helper ::PagesHelper

  # Via Devise
  before_action :authenticate_admin_user!

  before_action :set_page, only: [ :show, :edit, :update, :destroy ]

  public

    # GET /admin/pages
    def index
      @pages = Page.top_level.all
    end

    # GET /admin/pages/1
    def show
    end

    # GET /admin/pages/new
    def new
      @page = Page.new
    end

    # GET /admin/pages/1/edit
    def edit
    end

    # POST /admin/pages
    def create
      @page = Page.new( page_params )

      respond_to do | format |
        if @page.save
          format.html { redirect_to [:admin, @page], notice: 'Page was successfully created.' }
        else
          format.html { render :new }
        end
      end
    end

    # PATCH/PUT /admin/pages/1
    def update
      respond_to do | format |
        if @page.update( page_params )
          if @page.previous_changes.has_key?( 'raw_editor' )
            format.html { redirect_to [ :edit, :admin, @page ], notice: 'Editing style changed.' }
          else
            format.html { redirect_to [ :admin, @page ], notice: 'Page was successfully updated.' }
          end
        else
          format.html { render :edit }
        end
      end
    end

    # DELETE /admin/pages/1
    def destroy
      @page.destroy
      respond_to do | format |
        format.html { redirect_to admin_pages_url, notice: 'Page was successfully destroyed.' }
      end
    end

  private

    def determine_layout
      case action_name
        when 'show'
          'pages'
        else
          'admin'
      end
    end

    def set_page
      @page = Page.find_by_id_or_slug!( params[ :id ] )
    end

    def page_params
      params.require( :page ).permit( :title,
                                      :slug,
                                      :body,
                                      :page_id,
                                      :hidden,
                                      :raw_editor,
                                      :page_type,
                                      :form_selection_list_contents )
    end

end
