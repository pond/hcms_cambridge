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
    price_on_application
    price_per_seat
    price_physical
    name_physical

    category
  }

  public

    # GET /admin/encounters
    def index
      @encounters = Encounter.all.includes(:revisions)
    end

    # GET /admin/encounters/<id>
    def show
      if @encounter.might_include_price_details?
        flash.now[:alert] = "There might be price information included in this encounter's summary or description. Be careful to avoid price details in the summary or details areas, since these are seen by people who are sent details of the encounter as part of a gift."
      end

      @form_model = @encounter.form_class.new(pagelike: @encounter)
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
        Encounter.transaction do
          @encounter.destroy!
          fill_gap_if_necessary_at(@encounter.category_position)
        end

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

    # Given a category position, if there are no records in that position,
    # renumber all at a higher position down one to fill the gap. Call when a
    # gap may have been made by altering a record. If you want to ignore a
    # specific record if calling here *before* updating something.
    #
    # Returns "true" if higher-numbered categories were decreased by 1.
    #
    def fill_gap_if_necessary_at(category_position, ignoring_id: nil)
      scope = if ignoring_id.nil?
        Encounter
      else
        Encounter.where.not(id: ignoring_id)
      end

      if scope.where(category_position: category_position).none?
        Encounter
          .where("category_position > ?", category_position)
          .update_all("category_position = category_position - 1")

        return true
      else
        return false
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
      if params[:encounter] && params[:encounter].key?(:category_chooser)
        chosen_category = params[:encounter].delete(:category_chooser)
        params[:encounter][:category] = chosen_category if chosen_category.present?
      end

      clean_category         = params.dig(:encounter, :category)&.strip || ''
      safe_params            = self.encounter_params()
      safe_params[:category] = clean_category

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

      # There's some fiddling around here to maintain category positions. If a
      # new category is encountered, just add it to the end. Otherwise, use an
      # existing category. But if we're *changing* category on an existing
      # record and there aren't any others left in that category, then we must
      # shuffle higher-position categories down to fill the gap.

      result = Encounter.transaction do
        encounter_in_matching_category = Encounter.matching_category(clean_category).first

        if encounter_in_matching_category.present?
          safe_params[:category_position] = encounter_in_matching_category.category_position
        else
          safe_params[:category_position] = (Encounter.maximum(:category_position) || 0) + 1
        end

        if encounter.persisted? && encounter.category != clean_category
          did_fill_gap = fill_gap_if_necessary_at(
            encounter.category_position,
            ignoring_id: encounter.id
          )

          if did_fill_gap and safe_params[:category_position] > encounter.category_position
            safe_params[:category_position] -= 1
          end
        end

        encounter.persist!(safe_params, publish: params[:publish].present?)
      end

      if result.successful
        if encounter.previous_changes.key?('raw_editor')
          if result.published
            redirect_to([:edit, :admin, encounter], notice: 'Editor selection altered and other changes, if any, published.')
          else
            redirect_to([:edit, :admin, encounter], notice: 'Editor selection altered.')
          end
        elsif result.published
          redirect_to(
            admin_encounter_path(encounter.slug),
            notice: published_message
          )
        else
          redirect_to(
            admin_encounter_path(encounter.slug, revision: encounter.current_revision.id),
            notice: draft_message
          )
        end
      else
        render(render_on_fail)
      end
    end

    def encounter_params
      return params.require(:encounter).permit(PERMITTED_ENCOUNTER_PARAMS)
    end
end
