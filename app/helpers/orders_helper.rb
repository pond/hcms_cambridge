module OrdersHelper

  # Render the cost of the order as a formatted string, with currency symbol.
  #
  def ordershelp_amount(order)
    apphelp_money(
      order.amount_owed,
      currency:       order.event.currency,
      free_of_charge: order.event.free_of_charge?
    )
  end

  # Generates a "manage order" URL based on order ID and token.
  #
  def ordershelp_magic_link(order)
    return manage_order_url(
      order_id: order.id,
      token:    order.token,
    )
  end

  # Returns explanation text with a link to manage the given order, in HTML or
  # plain text. In each case, the returned string terminates with a newline.
  #
  def ordershelp_magic_link_markup(order, plain_text:)
    if plain_text
      text = <<~TEXT
        To manage your order, use this link:

          #{ordershelp_magic_link(order)}

        This expires on #{apphelp_human_time(order.token_expires_at)}.
      TEXT

      return text
    else
      html = <<~HTML.html_safe() # WARNING - must only HTML-safe text inside
        <p>
          To manage your order, use this link:
        </p>

        <ul>
          <li>
            <strong>
              #{link_to('Manage order', ordershelp_magic_link(order))}
            </strong>
            (expires on #{apphelp_human_time(order.token_expires_at)})
          </li>
        </ul>
      HTML

      return html
    end
  end
end
