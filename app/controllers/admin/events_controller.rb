class Admin::EventsController < ApplicationController

  layout :determine_layout

  before_action :authenticate_admin_user! # (via Devise)
  before_action :get_page
  before_action :get_event,            only: [:show, :destroy]
  before_action :get_editable_event,   only: [:edit, :update]
  before_action :build_editable_event, only: [:new,  :create]
  before_action :check_for_revision,   only: [:show, :edit, :update]

  PERMITTED_EVENT_PARAMS = %i{
    title
    slug
    event_hero_image
    summary
    body
    raw_editor

    state
    starts_at
    ends_at
    number_of_seats
    price_per_seat
    location

    on_archive_action
    on_archive_params_blog_id
  }

  public

    # GET /admin/pages/<page_id>/events
    def index
      @events = Event.where(page_id: @page.id).includes(:orders)
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

    # PATCH/PUT /admin/pages/<page_id>/events/<id>
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
      @event.destroy!

      redirect_to(
        admin_page_events_url( page_id: @page.id ),
        notice: 'Event deleted.'
      )
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
      safe_params               = self.event_params()
      on_archive_action         = safe_params.delete(:on_archive_action)
      on_archive_params         = {}
      on_archive_params_blog_id = safe_params.delete(:on_archive_params_blog_id)

      if on_archive_action == Event.on_archive_actions[:move]
        blog = Page.blogs.find_by_id(on_archive_params_blog_id)
        on_archive_params[:blog_id] == blog.id if blog.present?
      end

      [:number_of_seats, :price_per_seat].each do | attr |
        safe_params[attr] = '0' if safe_params[attr].blank?
      end

      if event.currency.present?
        parsed_amount = Monetize.parse(
          safe_params[:price_per_seat],
          event.currency
        )
        safe_params[:price_per_seat] = parsed_amount.cents
      else
        safe_params[:price_per_seat] = 0
      end

      [:starts_at, :ends_at].each do | attr |
        tz_datetime = Time.use_zone(Hcms.config.time_zone) do
          Time.zone.parse(safe_params[attr]) rescue Time.current - 1.year
        end

        safe_params[attr] = tz_datetime
      end

      event.assign_attributes(safe_params)
      debugger unless event.valid? && event.starts_at > Time.current

      result = event.persist!(safe_params, publish: params[:publish].present?)

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
      return params.require(:event).permit(PERMITTED_EVENT_PARAMS)
    end
end
