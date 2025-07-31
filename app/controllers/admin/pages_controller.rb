class Admin::PagesController < ApplicationController

  layout :determine_layout
  helper ::PagesHelper

  # Via Devise
  before_action :authenticate_admin_user!

  before_action :set_page, only: [:show, :edit, :update, :destroy]

  public

    # GET /admin/pages
    def index
      @pages = Page.top_level.includes(:revisions).load
    end

    # GET /admin/pages/1
    def show
      @revision = if params.key?(:revision)
        @page.revisions.find(params[:revision])
      else
        @page.published_revision
      end

      @form_model = @page&.form_class&.new
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
      @page  = Page.new
      result = @page.persist!(self.page_params(), publish: params[:publish].present?)

      if result.successful
        if result.published
          redirect_to [:admin, @page], notice: 'New page published.'
        else
          redirect_to [:admin, @page, {revision: @page.current_draft_revision.id}], notice: 'New draft page created.'
        end
      else
        render :new
      end
    end

    # PATCH/PUT /admin/pages/1
    def update
      result = @page.persist!(self.page_params(), publish: params[:publish].present?)

      if result.successful
        if @page.previous_changes.has_key?('raw_editor')
          if result.published
            redirect_to [:edit, :admin, @page], notice: 'Editing style altered and other changes, if any, published.'
          else
            redirect_to [:edit, :admin, @page], notice: 'Editing style altered.'
          end
        elsif result.published
          redirect_to [:admin, @page], notice: 'Page changes published.'
        elsif @page.current_revision.previously_new_record?
          redirect_to [:admin, @page, {revision: @page.current_revision.id}], notice: 'New draft revision created.'
        else
          redirect_to [:admin, @page, {revision: @page.current_revision.id}], notice: 'Draft revision updated.'
        end
      else
        render :edit
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
      params
        .require( :page )
        .permit(
          :title,
          :slug,
          :navigation_title,
          :body,
          :page_id,
          :hidden,
          :raw_editor,
          :page_type,
          :form_selection_list_contents,
          :form_selection_list_label,
        )
    end
end
