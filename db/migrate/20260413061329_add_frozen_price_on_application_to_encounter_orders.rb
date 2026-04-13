# Rationale follows that in
# "db/migrate/20260326230858_better_order_and_encounter_order_behaviour.rb".
#
class AddFrozenPriceOnApplicationToEncounterOrders < ActiveRecord::Migration[8.1]
  def change

    add_column :encounter_orders, :frozen_price_on_application, :boolean, null: true

    EncounterOrder.unscoped.joins(:encounter).update_all("frozen_price_on_application = encounters.price_on_application")

    change_column_null :encounter_orders, :frozen_price_on_application, false
  end
end
