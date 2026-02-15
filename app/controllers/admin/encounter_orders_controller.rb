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
  }

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
      safe_params = self.order_params()

      safe_params[:number_of_seats] = safe_params[:number_of_seats].to_i
      if safe_params[:number_of_seats] < 0
        safe_params[:number_of_seats] = 0
      end

      case safe_params[:has_physical]
        when 'true'
          safe_params[:has_physical] = true
        when 'false'
          safe_params[:has_physical] = false
        else
          safe_params[:has_physical] = nil
      end

      if safe_params[:amount_owed].present?
        parsed_amount = Monetize.parse(
          safe_params[:amount_owed],
          @encounter.currency
        )
        safe_params[:amount_owed] = parsed_amount.cents
      else
        amount_cents = @encounter.price_per_seat * safe_params[:number_of_seats]

        if safe_params[:has_physical] == true
          amount_cents += @encounter_order.encounter.price_physical.to_i
        end

        safe_params[:amount_owed] = amount_cents
      end

      @encounter_order.assign_attributes(safe_params)

      if @encounter_order.save
        @encounter_order.pay_state! if @encounter_order.amount_owed.zero?

        redirect_to(
          admin_encounter_encounter_order_path(
            encounter_id: @encounter_order.encounter.slug,
            id:           @encounter_order.id,
          ),
          notice: 'Encounter order set up successfully.'
        )
      else
        render :new
      end
    end

    # GET /admin/encounters/<encounter_id>/orders/edit/<id>
    def edit
    end

    # PATCH/PUT /admin/encounters/<encounter_id>/orders/<id>
    def update
      if params[:process] != 'state'
        return bail_out_with('Unrecognised order change requested') # NOTE EARLY EXIT
      end

      all_events   = EncounterOrder.aasm(:state).events.map(&:name).map(&:to_s)
      valid_events = @encounter_order.valid_events.map(&:name).map(&:to_s)
      event_name   = params[:event]

      if all_events.exclude?(event_name)
        return bail_out_with('Unrecognised order change requested')
      elsif valid_events.exclude?(event_name)
        return bail_out_with('That order cannot be changed in that way')
      else
        ActiveRecord::Base.transaction do
          stripe_payment_was_present = @encounter_order.stripe_payment.present?

          @encounter_order.send("#{event_name}_state!")
          notification = 'Order updated'

          if event_name == 'refund'
            if stripe_payment_was_present && @encounter_order.reload.stripe_payment.nil?
              notification = 'Refund successfully processed automatically via Stripe.'
            else
              notification = <<~STR
                Order marked as refunded locally only. No matter how it was paid
                for - e.g. bank transfer or a processor such as Stripe - please
                make sure that this mechansim has been, or is used to actually
                return the paid money.'
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
          alert: 'You cannot delete a paid-for order; process a refund instead.'
        )
      else
        @encounter_order.destroy!

        redirect_to(
          admin_encounter_encounter_orders_path(@encounter.slug),
          notice: 'Order deleted. Customer web links to this order will no longer work.'
        )
      end
    end

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

    # Redirect to the order 'show' page with a given alert message if @encounter_order
    # is set, else the index page with that message.
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

    def order_params
      return params.require(:encounter_order).permit(PERMITTED_ENCOUNTER_ORDER_PARAMS)
    end

end
