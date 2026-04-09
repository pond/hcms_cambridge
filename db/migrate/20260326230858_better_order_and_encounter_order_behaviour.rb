class BetterOrderAndEncounterOrderBehaviour < ActiveRecord::Migration[8.1]
  def change

    # Turn off "can be null" for Encounter Orders, with default of "false".
    #
    change_column_null :encounter_orders, :has_physical, false, false

    # Now add a column so that we explicitly know if the user chooses to include
    # or exclude a physical item, or if it's preset by the admin.
    #
    add_column :encounter_orders, :user_chooses_has_physical, :boolean, null: false, default: true

    # Invoices like to show an indication of discounts, and previously did this
    # by e.g. "order.event.price_per_seat", but if that price is edited then the
    # invoice information would change. Existing invoices should not do that, so
    # add columns to record prices-at-time-of-purchase.
    #
    add_column :orders,           :frozen_price_per_seat, :integer, null: true
    add_column :encounter_orders, :frozen_price_per_seat, :integer, null: true
    add_column :encounter_orders, :frozen_price_physical, :integer, null: true

    Order         .unscoped.joins(:event    ).update_all("frozen_price_per_seat =     events.price_per_seat")
    EncounterOrder.unscoped.joins(:encounter).update_all("frozen_price_per_seat = encounters.price_per_seat")
    EncounterOrder.unscoped.joins(:encounter).update_all("frozen_price_physical = encounters.price_physical")

    # Price-per-seat must always be set; physical price is "nil" if no physical
    # product is (or rather, at order creation time, *was*) not offered.
    #
    change_column_null :orders,           :frozen_price_per_seat, false
    change_column_null :encounter_orders, :frozen_price_per_seat, false

  end
end
