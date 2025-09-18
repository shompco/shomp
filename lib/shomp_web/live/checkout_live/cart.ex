defmodule ShompWeb.CheckoutLive.Cart do
  use ShompWeb, :live_view

  alias Shomp.Carts
  alias Shomp.Payments

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  def mount(%{"cart_id" => cart_id}, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    cart = Carts.list_user_carts(user_id)
    |> Enum.find(&(&1.id == String.to_integer(cart_id)))

    case cart do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Cart not found")
         |> push_navigate(to: ~p"/cart")}

      cart ->
        IO.puts("=== CART LOADED IN MOUNT ===")
        IO.puts("Cart ID: #{cart.id}")
        IO.puts("Cart Items: #{length(cart.cart_items)}")
        IO.puts("Cart Total: #{cart.total_amount}")

        socket = socket
                 |> assign(:cart, cart)
                 |> assign(:page_title, "Checkout Cart")

        {:ok, socket}
    end
  end



  def handle_event("checkout", _params, socket) do
    cart = socket.assigns.cart
    user_id = socket.assigns.current_scope.user.id

    IO.puts("=== CART CHECKOUT DEBUG ===")
    IO.puts("Cart ID: #{cart.id}")
    IO.puts("User ID: #{user_id}")
    IO.puts("Cart Items: #{length(cart.cart_items)}")

    # Create Stripe checkout session for the entire cart
    case Payments.create_cart_checkout_session(cart.id, user_id) do
      {:ok, session} ->
        IO.puts("Checkout session created successfully")
        IO.puts("Session URL: #{session.url}")
        {:noreply, redirect(socket, external: session.url)}

      {:error, reason} ->
        IO.puts("Checkout session failed: #{inspect(reason)}")

        error_message = case reason do
          :cart_not_found ->
            "Cart not found. Please refresh the page and try again."
          :no_stripe_product ->
            "Some products in your cart are not available for online purchase. Please contact the store owner."
          _ ->
            "Failed to create checkout session. Please try again or contact support."
        end

        {:noreply,
         socket
         |> put_flash(:error, error_message)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Checkout</h1>
          <p class="text-lg text-gray-600 mt-2">Review your order and complete payment</p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Cart Items -->
          <div class="lg:col-span-2">
            <div class="bg-white shadow rounded-lg">
              <div class="px-6 py-4 border-b border-gray-200">
                <h2 class="text-lg font-medium text-gray-900">Order Summary</h2>
                <p class="text-sm text-gray-500"><%= @cart.store.name %></p>
              </div>

              <div class="divide-y divide-gray-200">
                <%= for cart_item <- @cart.cart_items do %>
                  <div class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center space-x-4">
                        <div class="flex-shrink-0">
                          <div class="w-16 h-16 bg-gray-200 rounded-lg flex items-center justify-center">
                            <svg class="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                            </svg>
                          </div>
                        </div>

                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium text-gray-900 truncate">
                            <%= cart_item.product.title %>
                          </p>
                          <p class="text-sm text-gray-500 truncate">
                            <%= cart_item.product.description %>
                          </p>
                          <p class="text-sm text-gray-500">
                            Qty: <%= cart_item.quantity %> × $<%= cart_item.price %>
                          </p>
                        </div>
                      </div>

                      <div class="text-right">
                        <p class="text-lg font-semibold text-gray-900">
                          $<%= Carts.CartItem.total_price(cart_item) %>
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Order Summary -->
          <div class="lg:col-span-1">
            <div class="bg-white shadow rounded-lg sticky top-8">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-medium text-gray-900">Order Total</h3>
              </div>

              <div class="px-6 py-4 space-y-4">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500">Subtotal</span>
                  <span class="text-gray-900">$<%= @cart.total_amount %></span>
                </div>

                <div class="flex justify-between text-sm">
                  <span class="text-gray-500">Tax</span>
                  <span class="text-gray-900">$0.00</span>
                </div>

                <div class="border-t border-gray-200 pt-4">
                  <div class="flex justify-between text-lg font-semibold">
                    <span class="text-gray-900">Total</span>
                    <span class="text-gray-900">$<%= @cart.total_amount %></span>
                  </div>
                </div>

                <button
                  phx-click="checkout"
                  phx-disable-with="Creating checkout..."
                  class="btn btn-primary w-full"
                  id="checkout-button"
                >
                  Proceed to Payment
                </button>



                <div class="text-center">
                  <.link href={~p"/cart"} class="text-sm text-blue-600 hover:text-blue-800">
                    ← Back to Cart
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
