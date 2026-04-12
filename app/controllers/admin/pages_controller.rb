class Admin::PagesController < ApplicationController

  layout :determine_layout
  helper ::PagesHelper

  before_action :authenticate_admin_user! # (via Devise)

  before_action :get_page,            only: [:show, :destroy]
  before_action :get_editable_page,   only: [:edit, :update]
  before_action :build_editable_page, only: [:new,  :create]
  before_action :check_for_revision,  only: [:show, :edit, :update]

  public

    # GET /admin/pages
    def index
      @pages = Page.top_level.includes(:revisions).load
    end

    # GET /admin/pages/1
    def show
      @form_model = @page&.form_class&.new(pagelike: @page)
    end

    # GET /admin/pages/new
    def new
      @page.hide_date_and_time = Hcms.config.hide_booking_date
    end

    # GET /admin/pages/1/edit
    def edit
    end

    # POST /admin/pages
    def create
      handle_form_submission(
        page:              @page,
        render_on_fail:    :new,
        draft_message:     'New draft page created.',
        published_message: 'New page published.'
      )
    end

    # PATCH/PUT /admin/pages/1
    def update
      handle_form_submission(
        page:              @page,
        render_on_fail:    :edit,
        draft_message:     'Changes saved as draft.',
        published_message: 'Page changes published.'
      )
    end

    # DELETE /admin/pages/1
    def destroy
      @page.destroy!

      redirect_to(admin_pages_url(), notice: 'Page deleted.')
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

    def get_page
      @page = Page.find_by_id_or_slug!(params[:id])
    end

    def get_editable_page
      self.get_page.for_edit!
    end

    def build_editable_page
      @page = Page.new.for_edit!
    end

    def check_for_revision
      if params.key?(:revision)
        revision = @page.revisions.find(params[:revision])
        @page.use_revision!(revision)
      end
    end

    # Used by #create and #update; internal API, see callers for examples.
    #
    def handle_form_submission(
      page:,
      render_on_fail:,
      draft_message:,
      published_message:
    )
      result = page.persist!(self.page_params(), publish: params[:publish].present?)

      if result.successful
        if page.previous_changes.key?('raw_editor')
          if result.published
            redirect_to([:edit, :admin, page], notice: 'Editor selection altered and other changes, if any, published.')
          else
            redirect_to([:edit, :admin, page], notice: 'Editor selection altered.')
          end
        elsif result.published
          redirect_to(admin_page_path(page.slug), notice: published_message)
        else
          redirect_to(admin_page_path(page.slug, revision: page.current_revision.id), notice: draft_message)
        end
      else
        render(render_on_fail)
      end
    end

    def page_params
      params
        .require(:page)
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
          :hide_date_and_time,
        )
    end
end
