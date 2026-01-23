class Admin::EncountersController < ApplicationController

  layout :determine_layout

  before_action :authenticate_admin_user! # (via Devise)
  before_action :get_encounter,            only: [:show, :destroy]
  before_action :get_editable_encounter,   only: [:edit, :update]
  before_action :build_editable_encounter, only: [:new,  :create]
  before_action :check_for_revision,       only: [:show, :edit, :update]

  PERMITTED_ENCOUNTER_PARAMS = %i{
    title
    slug
    encounter_hero_image
    summary
    body
    raw_editor

    location
    price_per_seat
    price_physical
    name_physical
  }

  public

    # GET /admin/encounters
    def index
      @encounters = Encounter
        .all
        .includes(:revisions)#, :encounter_orders, :confirmed_encounter_orders)
    end

    # GET /admin/encounters/<id>
    def show
    end

    # GET /admin/encounters/new
    def new
    end

    # GET /admin/encounters/edit/<id>
    def edit
    end

    # POST /admin/encounters
    def create
      handle_form_submission(
        encounter:         @encounter,
        render_on_fail:    :new,
        draft_message:     'New draft encounter created.',
        published_message: 'New encounter published.'
      )
    end

    # PATCH/PUT /admin/encounters/<id>
    def update
      handle_form_submission(
        encounter:         @encounter,
        render_on_fail:    :edit,
        draft_message:     'Changes saved as draft.',
        published_message: 'Encounter changes published.'
      )
    end

    # DELETE /admin/encounters/<id>
    def destroy
      refuse_deletion_count = @encounter.encounter_orders.where(state: Order::REFUSE_EVENT_DELETION_STATES).count

      if refuse_deletion_count.zero?
        @encounter.destroy!

        redirect_to(
          admin_encounters_url(),
          notice: 'Encounter deleted.'
        )
      else
        irrevocable_count = @encounter.encounter_orders.where(state: Order::IRREVOCABLE_REFUSE_EVENT_DELETION_STATES).count

        if irrevocable_count.zero?
          redirect_to(
            admin_encounters_url(),
            alert: 'This encounter has in-progress orders so it cannot be deleted. Cancel in-flight orders first, then try again.'
          )
        else
          redirect_to(
            admin_encounters_url(),
            alert: 'This encounter has completed orders so it cannot be deleted, since customer payment invoices refer to it.'
          )
        end
      end
    end

  private

    def determine_layout
      case action_name
        when 'show'
          'encounters'
        else
          'admin'
      end
    end

    def get_encounter
      @encounter = Encounter.find_by_id_or_slug!(params[:id])
    end

    def get_editable_encounter
      self.get_encounter.for_edit!
    end

    def build_editable_encounter
      @encounter = Encounter.new.for_edit!
    end

    def check_for_revision
      if params.key?(:revision)
        revision = @encounter.revisions.find(params[:revision])
        @encounter.use_revision!(revision)
      end
    end

    # Used by #create and #update; internal API, see callers for examples.
    #
    def handle_form_submission(
      encounter:,
      render_on_fail:,
      draft_message:,
      published_message:
    )
      safe_params = self.encounter_params()

      if safe_params[:price_per_seat].blank?
        safe_params[:price_per_seat] = '0'
      end

      if safe_params[:price_physical].blank?
        safe_params[:price_physical] = nil
        safe_params[:name_physical ] = nil
      end

      [:price_per_seat, :price_physical].each do | attr |
        if safe_params[attr].present?
          parsed_amount = Monetize.parse(
            safe_params[attr],
            encounter.currency
          )
          safe_params[attr] = parsed_amount.cents
        end
      end

      result = encounter.persist!(safe_params, publish: params[:publish].present?)

      if result.successful
        if encounter.previous_changes.has_key?('raw_editor')
          if result.published
            redirect_to([:edit, :admin, encounter], notice: 'Editor selection altered and other changes, if any, published.')
          else
            redirect_to([:edit, :admin, encounter], notice: 'Editor selection altered.')
          end
        elsif result.published
          redirect_to(admin_encounter_path(encounter.slug), notice: published_message)
        else
          redirect_to(admin_encounter_path(encounter.slug, revision: encounter.current_revision.id), notice: draft_message)
        end
      else
        render(render_on_fail)
      end
    end

    def encounter_params
      return params.require(:encounter).permit(PERMITTED_ENCOUNTER_PARAMS)
    end
end
#
