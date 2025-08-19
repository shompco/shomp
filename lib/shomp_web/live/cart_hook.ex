defmodule ShompWeb.CartHook do
  @moduledoc """
  Hook for updating cart count in the header.
  """
  
  use Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      # Get cart count for the current user
      cart_count = get_cart_count(socket.assigns.current_scope.user.id)
      
      socket = assign(socket, :cart_count, cart_count)
      
      # Push the cart count to the client immediately
      socket = push_event(socket, "cart-count-updated", %{count: cart_count})
      
      {:cont, socket}
    else
      # No authenticated user, set cart count to 0
      socket = assign(socket, :cart_count, 0)
      
      # Push the cart count to the client immediately
      socket = push_event(socket, "cart-count-updated", %{count: 0})
      
      {:cont, socket}
    end
  end

  def on_mount(:update_count, _params, _session, socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      # Update cart count
      cart_count = get_cart_count(socket.assigns.current_scope.user.id)
      
      socket = assign(socket, :cart_count, cart_count)
      
      # Push the updated count to the client
      socket = push_event(socket, "cart-count-updated", %{count: cart_count})
      
      {:cont, socket}
    else
      # No authenticated user, set cart count to 0
      socket = assign(socket, :cart_count, 0)
      socket = push_event(socket, "cart-count-updated", %{count: 0})
      {:cont, socket}
    end
  end

  defp get_cart_count(user_id) do
    alias Shomp.Carts
    
    carts = Carts.list_user_carts(user_id)
    
    carts
    |> Enum.reduce(0, fn cart, acc -> 
      acc + Carts.Cart.item_count(cart)
    end)
  end
end
