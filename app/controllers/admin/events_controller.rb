class Admin::EventsController < ApplicationController

  layout :determine_layout

  # Via Devise
  before_action :authenticate_admin_user!
  before_action :get_page
  before_action :get_event,            only: [:show, :destroy]
  before_action :get_editable_event,   only: [:edit, :update]
  before_action :build_editable_event, only: [:new,  :create]
  before_action :check_for_revision,   only: [:show, :edit, :update]

  public

    # GET /admin/pages/<page_id>/events
    def index
      @events = Event.where(page_id: @page.id)
    end

    # GET /admin/pages/<page_id>/events/<id>
    def show
    end

    # GET /admin/pages/<page_id>/events/new
    def new
    end

    # GET /admin/pages/<page_id>/events/edit/<id>
    def edit
    end

    # POST /admin/pages/<page_id>/events
    def create
      handle_form_submission(
        event:           @event,
        render_on_fail:    :new,
        draft_message:     'New draft event created.',
        published_message: 'New event published.'
      )
    end

    # PATCH/PUT //admin/pages/<page_id>/events/<id>
    def update
      handle_form_submission(
        event:           @event,
        render_on_fail:    :edit,
        draft_message:     'Changes saved as draft.',
        published_message: 'Event changes published.'
      )
    end

    # DELETE /admin/pages/<page_id>/events/<id>
    def destroy
      @event.destroy

      respond_to do | format |
        format.html do
          redirect_to(
            admin_page_events_url( page_id: @page.id ),
            notice: 'Event deleted.'
          )
        end
      end
    end

  private

    def determine_layout
      case action_name
        when 'show'
          'events'
        else
          'admin'
      end
    end

    def get_page
      @page = Page.find_by_id_or_slug!(params[:page_id])
    end

    def get_event
      @event = Event.find_by_id_or_slug!(params[:id])
    end

    def get_editable_event
      self.get_event.for_edit!
    end

    def build_editable_event
      @event = @page.events.build.for_edit!
    end

    def check_for_revision
      if params.key?(:revision)
        revision = @event.revisions.find(params[:revision])
        @event.use_revision!(revision)
      end
    end

    # Used by #create and #update; internal API, see callers for examples.
    #
    def handle_form_submission(
      event:,
      render_on_fail:,
      draft_message:,
      published_message:
    )
      upon_archiving_choice = params[:event]&.delete(:upon_archiving)

      result = event.persist!(self.event_params(), publish: params[:publish].present?)

      if result.successful
        if event.previous_changes.has_key?('raw_editor')
          if result.published
            redirect_to([:edit, :admin, event.page, event], notice: 'Editor selection altered and other changes, if any, published.')
          else
            redirect_to([:edit, :admin, event.page, event], notice: 'Editor selection altered.')
          end
        elsif result.published
          redirect_to(admin_page_event_path(event.page.slug, event.slug), notice: published_message)
        else
          redirect_to(admin_page_event_path(event.page.slug, event.slug, revision: event.current_revision.id), notice: draft_message)
        end
      else
        render(render_on_fail)
      end
    end

    def event_params
      params
        .require(:event)
        .permit(
          :title,
          :slug,
          :event_hero_image,
          :summary,
          :body,
          :raw_editor,

          :starts_at,
          :ends_at,
          :number_of_seats,
          :price_per_seat,
          :currency,
        )
    end
end
