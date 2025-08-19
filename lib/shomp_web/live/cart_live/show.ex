defmodule ShompWeb.CartLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Carts
  alias Shomp.Payments


  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    
    # Get all active carts for the user
    carts = Carts.list_user_carts(user_id)
    
    socket = socket
             |> assign(:carts, carts)
             |> assign(:page_title, "Shopping Cart")
    
    {:ok, socket}
  end

  def handle_event("add_to_cart", %{"product_id" => product_id, "store_id" => store_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    
    case Carts.get_or_create_cart(user_id, store_id) do
      {:ok, cart} ->
        case Carts.add_to_cart(cart.id, product_id) do
          {:ok, _cart_item} ->
            # Refresh the carts
            updated_carts = Carts.list_user_carts(user_id)
            socket = assign(socket, :carts, updated_carts)
            
            # Update cart count in header
            cart_count = Enum.reduce(updated_carts, 0, fn cart, acc -> 
              acc + Carts.Cart.item_count(cart)
            end)
            socket = assign(socket, :cart_count, cart_count)
            socket = push_event(socket, "cart-count-updated", %{count: cart_count})
            
            {:noreply, 
             socket
             |> put_flash(:info, "Product added to cart!")}
          
          {:error, _changeset} ->
            {:noreply, 
             socket
             |> put_flash(:error, "Failed to add product to cart.")}
        end
      
      {:error, _changeset} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to create cart.")}
    end
  end

  def handle_event("remove_from_cart", %{"cart_id" => cart_id, "product_id" => product_id}, socket) do
    case Carts.remove_from_cart(cart_id, product_id) do
      {:ok, :removed} ->
        # Refresh the carts
        user_id = socket.assigns.current_scope.user.id
        updated_carts = Carts.list_user_carts(user_id)
        socket = assign(socket, :carts, updated_carts)
        
        # Update cart count in header
        cart_count = Enum.reduce(updated_carts, 0, fn cart, acc -> 
          acc + Carts.Cart.item_count(cart)
        end)
        socket = assign(socket, :cart_count, cart_count)
        socket = push_event(socket, "cart-count-updated", %{count: cart_count})
        
        {:noreply, 
         socket
         |> put_flash(:info, "Product removed from cart!")}
      
      {:error, :not_found} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Product not found in cart.")}
      
      {:error, _reason} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to remove product from cart.")}
    end
  end

  def handle_event("update_quantity", %{"cart_item_id" => cart_item_id, "quantity" => quantity}, socket) do
    case Carts.update_cart_item_quantity(cart_item_id, String.to_integer(quantity)) do
      {:ok, _updated_item} ->
        # Refresh the carts
        user_id = socket.assigns.current_scope.user.id
        updated_carts = Carts.list_user_carts(user_id)
        socket = assign(socket, :carts, updated_carts)
        
        # Update cart count in header
        cart_count = Enum.reduce(updated_carts, 0, fn cart, acc -> 
          acc + Carts.Cart.item_count(cart)
        end)
        socket = assign(socket, :cart_count, cart_count)
        socket = push_event(socket, "cart-count-updated", %{count: cart_count})
        
        {:noreply, 
         socket
         |> put_flash(:info, "Quantity updated!")}
      
      {:error, _changeset} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to update quantity.")}
    end
  end

  def handle_event("clear_cart", %{"cart_id" => cart_id}, socket) do
    case Carts.clear_cart(cart_id) do
      {:ok, :cleared} ->
        # Refresh the carts
        user_id = socket.assigns.current_scope.user.id
        updated_carts = Carts.list_user_carts(user_id)
        socket = assign(socket, :carts, updated_carts)
        
        # Update cart count in header
        cart_count = Enum.reduce(updated_carts, 0, fn cart, acc -> 
          acc + Carts.Cart.item_count(cart)
        end)
        socket = assign(socket, :cart_count, cart_count)
        socket = push_event(socket, "cart-count-updated", %{count: cart_count})
        
        {:noreply, 
         socket
         |> put_flash(:info, "Cart cleared!")}
      
      _ ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to clear cart.")}
    end
  end

  def handle_event("checkout_cart", %{"cart_id" => cart_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    
    # Find the specific cart
    cart = Enum.find(socket.assigns.carts, &(&1.id == String.to_integer(cart_id)))
    
    case cart do
      nil ->
        {:noreply, 
         socket
         |> put_flash(:error, "Cart not found. Please refresh the page and try again.")}
      
      cart ->
        # Create Stripe checkout session directly for this cart
        case Payments.create_cart_checkout_session(cart.id, user_id) do
          {:ok, session} ->
            # Redirect to Stripe checkout
            {:noreply, redirect(socket, external: session.url)}
          
          {:error, reason} ->
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
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Shopping Cart</h1>
          <p class="text-lg text-gray-600 mt-2">Review and manage your items</p>
        </div>

        <%= if Enum.empty?(@carts) do %>
          <!-- Empty Cart -->
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4m0 0L7 13m0 0l-2.5 5M7 13l2.5 5m6-5v6a2 2 0 01-2 2H9a2 2 0 01-2-2v-6m6 0V9a2 2 0 00-2-2H9a2 2 0 00-2 2v4.01" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">Your cart is empty</h3>
            <p class="mt-1 text-sm text-gray-500">Start shopping to add items to your cart.</p>
            <div class="mt-6">
              <a href="/" class="btn btn-primary">
                Browse Products
              </a>
            </div>
          </div>
        <% else %>
          <!-- Cart Items by Store -->
          <div class="space-y-8">
            <%= for cart <- @carts do %>
              <div class="bg-white shadow rounded-lg">
                <!-- Store Header -->
                <div class="px-6 py-4 border-b border-gray-200">
                  <div class="flex items-center justify-between">
                    <div>
                      <h2 class="text-lg font-medium text-gray-900"><%= cart.store.name %></h2>
                      <p class="text-sm text-gray-500"><%= length(cart.cart_items) %> items</p>
                    </div>
                    <div class="flex items-center space-x-2">
                      <button phx-click="clear_cart" phx-value-cart_id={cart.id} class="btn btn-sm btn-outline btn-error">
                        Clear Cart
                      </button>
                    </div>
                  </div>
                </div>

                <!-- Cart Items -->
                <div class="divide-y divide-gray-200">
                  <%= for cart_item <- cart.cart_items do %>
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
                              $<%= cart_item.price %> each
                            </p>
                          </div>
                        </div>
                        
                        <div class="flex items-center space-x-4">
                          <!-- Quantity Controls -->
                          <div class="flex items-center space-x-2">
                            <button phx-click="update_quantity" phx-value-cart_item_id={cart_item.id} phx-value-quantity={cart_item.quantity - 1} 
                                    class="btn btn-sm btn-circle btn-outline" disabled={cart_item.quantity <= 1}>
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
                              </svg>
                            </button>
                            
                            <span class="text-sm font-medium text-gray-900 w-8 text-center">
                              <%= cart_item.quantity %>
                            </span>
                            
                            <button phx-click="update_quantity" phx-value-cart_item_id={cart_item.id} phx-value-quantity={cart_item.quantity + 1} 
                                    class="btn btn-sm btn-circle btn-outline">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                              </svg>
                            </button>
                          </div>
                          
                          <!-- Item Total -->
                          <div class="text-right">
                            <p class="text-lg font-semibold text-gray-900">
                              $<%= Carts.CartItem.total_price(cart_item) %>
                            </p>
                          </div>
                          
                          <!-- Remove Button -->
                          <button phx-click="remove_from_cart" phx-value-cart_id={cart.id} phx-value-product_id={cart_item.product_id} 
                                  class="btn btn-sm btn-outline btn-error">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Cart Summary -->
                <div class="px-6 py-4 bg-gray-50 border-t border-gray-200">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm text-gray-500">Total Items: <%= Carts.Cart.item_count(cart) %></p>
                      <p class="text-lg font-semibold text-gray-900">Total: $<%= cart.total_amount %></p>
                    </div>
                    
                    <button phx-click="checkout_cart" phx-value-cart_id={cart.id} phx-disable-with="Creating checkout..." class="btn btn-primary">
                      Proceed to Payment
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
