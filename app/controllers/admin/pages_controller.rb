class Admin::PagesController < ApplicationController

  layout :determine_layout
  helper ::PagesHelper

  # Via Devise
  before_action :authenticate_admin_user!

  before_action :set_admin_page, only: [ :show, :edit, :update, :destroy ]

  public

    # GET /admin/pages
    def index
      @admin_pages = Admin::Page.top_level.all
    end

    # GET /admin/pages/1
    def show
      @page = @admin_page # for 'pages' layout
    end

    # GET /admin/pages/new
    def new
      @admin_page = Admin::Page.new
    end

    # GET /admin/pages/1/edit
    def edit
    end

    # POST /admin/pages
    def create
      @admin_page = Admin::Page.new( admin_page_params )

      respond_to do | format |
        if @admin_page.save
          format.html { redirect_to @admin_page, notice: 'Page was successfully created.' }
        else
          format.html { render :new }
        end
      end
    end

    # PATCH/PUT /admin/pages/1
    def update
      respond_to do | format |
        if @admin_page.update( admin_page_params )
          if @admin_page.previous_changes.has_key?( 'raw_editor' )
            format.html { redirect_to edit_admin_page_url( @admin_page ), notice: 'Editing style changed.' }
          else
            format.html { redirect_to @admin_page, notice: 'Page was successfully updated.' }
          end
        else
          format.html { render :edit }
        end
      end
    end

    # DELETE /admin/pages/1
    def destroy
      @admin_page.destroy
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

    def set_admin_page
      @admin_page = Admin::Page.find( params[ :id ] )
    end

    def admin_page_params
      params.require( :admin_page ).permit( :title,
                                            :body,
                                            :page_id,
                                            :hidden,
                                            :raw_editor,
                                            :page_type,
                                            :form_selection_list_contents )
    end

end
