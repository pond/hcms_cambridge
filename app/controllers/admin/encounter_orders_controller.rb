class Admin::EncounterOrdersController < ApplicationController

  layout 'admin'

  before_action :authenticate_admin_user! # (via Devise)
  before_action :get_encounter
  before_action :get_order, except: [:index]

  PERMITTED_ENCOUNTER_ORDER_PARAMS = %i{
    name
    email
    phone_number
    address

    notes_to_buyer
    has_physical
    starts_at
    starts_at_kind
    number_of_seats
    amount_owed

    supported_payment_method_other_details
  }

  PERMITTED_ENCOUNTER_ORDER_PARAMS << { :supported_payment_methods => [] }
  PERMITTED_ENCOUNTER_ORDER_PARAMS << { encounter_order_items_attributes: [
    :id, :description, :amount_owed, :_destroy
  ] }

  # ============================================================================
  # PUBLIC INSTANCE METHODS
  # ============================================================================
  #
  public

    # GET /admin/encounters/<encounter_id>/orders
    def index
      @encounter_orders = @encounter.encounter_orders.includes(:encounter)
    end

    # GET /admin/encounters/<encounter_id>/orders/<id>
    def show
    end

    # GET /admin/encounters/<encounter_id>/orders/new
    def new
      @encounter_order = EncounterOrder.new(encounter: @encounter)
      @encounter_order.starts_at_kind = EncounterOrder::STARTS_AT_KIND_OPEN_ENDED
    end

    # POST /admin/encounters/<encounter_id>/orders
    def create
      @encounter_order = EncounterOrder.new(encounter: @encounter)

      handle_form_submission(
        encounter_order:    @encounter_order,
        render_on_fail:     :new,
        message_on_success: 'Encounter booking set up successfully.',
      )
    end

    # GET /admin/encounters/<encounter_id>/orders/edit/<id>
    def edit
      @encounter_order = EncounterOrder.find(params[:id])

      unless @encounter_order.admin_can_make_amendments?
        # bail_out_with("This booking is not in a state that permits amendments.")
      end
    end

    # PATCH/PUT /admin/encounters/<encounter_id>/orders/<id>
    #
    # ** IMPORTANT! **
    #
    # This is used for two things. One is the typical Rails edit-update cycle
    # (see #edit above). The other is for buttons driven off the state machine
    # that PATCH here directly with params[:process] set to "state" as an
    # indicator. The code expects either that or permitted params for an update,
    # else it'll bail out early with a complaint.
    #
    def update
      @encounter_order = EncounterOrder.find(params[:id])
      @encounter_order.with_lock do

        # What if, say, the customer paid while the admin was editing the item?
        #
        if ! @encounter_order.admin_can_make_amendments?
          bail_out_with('This booking is no longer in a state that permits amendments.')
          return # NOTE EARLY EXIT
        end

        unless params[:process] == 'state'
          if params.key?(:encounter_order)
            handle_form_submission(
              encounter_order:    @encounter_order,
              render_on_fail:     :edit,
              message_on_success: 'Booking successfully amended.'
            )
          else
            bail_out_with('Unrecognised booking change requested') # NOTE EARLY EXIT
          end

          return # NOTE EARLY EXIT
        end

        all_events   = EncounterOrder.aasm(:state).events.map(&:name).map(&:to_s)
        valid_events = @encounter_order.valid_events.map(&:name).map(&:to_s)
        event_name   = params[:event]

        if all_events.exclude?(event_name)
          return bail_out_with('Unrecognised booking change requested')
        elsif valid_events.exclude?(event_name)
          return bail_out_with('That booking cannot be changed in that way')
        else
          stripe_payment_was_present = @encounter_order.stripe_payment.present?

          @encounter_order.send("#{event_name}_state!")
          notification = 'Booking updated'

          if event_name == 'refund'
            if stripe_payment_was_present && @encounter_order.reload.stripe_payment.nil?
              notification = 'Refund successfully processed automatically via Stripe.'
            else
              notification = <<~STR
                Booking marked as refunded locally only. No matter how it was
                paid for - e.g. bank transfer or a processor such as Stripe -
                please make sure that this mechansim has been, or is used to
                actually return the paid money.'
              STR
            end
          end

          redirect_to(
            admin_encounter_encounter_orders_path(@encounter.slug),
            notice: notification
          )
        end
      end
    end

    # DELETE /admin/encounters/<encounter_id>/orders/<id>
    #
    # See notes on the public OrdersController#destroy about this; the admin UI
    # usually doesn't delete orders, just maybe cancels them. But if the admin
    # really wants to delete something, well - they can.
    #
    def destroy
      flash_hash = if @encounter_order.state_paid?
        redirect_to(
          admin_encounter_encounter_order_path(encounter_id: @encounter.slug, id: @encounter_order.id),
          alert: 'You cannot delete a paid-for booking; process a refund instead.'
        )
      else
        @encounter_order.destroy!

        redirect_to(
          admin_encounter_encounter_orders_path(@encounter.slug),
          notice: 'Booking deleted. Customer web links to this booking will no longer work.'
        )
      end
    end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called before-action.
    #
    def get_encounter
      @encounter   = Encounter&.find_by_slug(params[:encounter_id])
      @encounter ||= Encounter&.find_by_id(params[:encounter_id])

      if @encounter.nil?
        redirect_to admin_pages_path(), alert: 'Sorry, that encounter seems to have disappeared!'
      end
    end

    # Called before-action.
    #
    def get_order
      @encounter_order = EncounterOrder.find_by_id(params[:id])
    end

    # Redirect to the order 'show' page with a given alert message if
    # @encounter_order is set, else the index page with that message.
    #
    def bail_out_with(alert_message)
      path = if @encounter_order.nil?
        admin_encounter_encounter_orders_path(encounter_id: @encounter.slug)
      else
        admin_encounter_encounter_order_path(
          encounter_id: @encounter_order.encounter.slug,
          id:           @encounter_order.id
        )
      end

      return redirect_to(path, alert: alert_message)
    end

    # Used by #create and #update; internal API, see callers for examples. If
    # calling for an update, you almost certainly should have locked the record
    # first!
    #
    def handle_form_submission(
      encounter_order:,
      render_on_fail:,
      message_on_success:
    )
      safe_params = self.encounter_order_params()
      safe_params[:number_of_seats] = safe_params[:number_of_seats].to_i

      if safe_params[:number_of_seats] < 0
        safe_params[:number_of_seats] = 0
      end

      case safe_params[:has_physical]
        when 'true'
          safe_params[:user_chooses_has_physical] = false
          safe_params[:has_physical             ] = true
        when 'false'
          safe_params[:user_chooses_has_physical] = false
          safe_params[:has_physical             ] = false
        else
          safe_params[:user_chooses_has_physical] = true
          safe_params[:has_physical             ] = false
      end

      if safe_params[:amount_owed].present?
        normalise_amount_owed!(
          for_encounter:        @encounter,
          updating_params_hash: safe_params
        )
      else
        amount_cents = @encounter.price_per_seat * safe_params[:number_of_seats]

        if safe_params[:has_physical] == true
          amount_cents += encounter_order.frozen_price_physical.to_i
        end

        safe_params[:amount_owed] = amount_cents
      end

      if safe_params[:encounter_order_items_attributes].present?
        safe_params[:encounter_order_items_attributes].each do | _key, eoi_params_hash_by_ref |
          normalise_amount_owed!(
            for_encounter:        @encounter,
            updating_params_hash: eoi_params_hash_by_ref
          )
        end
      end

      encounter_order.assign_attributes(safe_params)

      if encounter_order.save
        encounter_order.pay_state! if encounter_order.amount_owed.zero?

        redirect_to(
          admin_encounter_encounter_order_path(
            encounter_id: encounter_order.encounter.slug,
            id:           encounter_order.id,
          ),
          notice: message_on_success
        )
      else
        render(render_on_fail)
      end
    end

    # For a given encounter and a given params hash/subhash which might have an
    # "amount_owed" key with, if present, a String value, parse that key's value
    # as a money amount using the encounter's currency and write back the amount
    # owed as an Integer into the given hash.
    #
    def normalise_amount_owed!(for_encounter:, updating_params_hash:)
      if updating_params_hash[:amount_owed].present?
        parsed_amount = Monetize.parse(
          updating_params_hash[:amount_owed],
          for_encounter.currency
        )
        updating_params_hash[:amount_owed] = parsed_amount.cents
      end
    end

    def encounter_order_params
      return params.require(:encounter_order).permit(PERMITTED_ENCOUNTER_ORDER_PARAMS)
    end

end
