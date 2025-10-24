module OrdersHelper
  def ordershelp_amount(order)
    apphelp_money(
      order.amount_owed,
      free_of_charge: order.event.free_of_charge?
    )
  end
end
