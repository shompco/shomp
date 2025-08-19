defmodule ShompWeb.ProductLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Products

  @impl true
  def mount(%{"store_slug" => store_slug, "id" => id}, _session, socket) do
    case Products.get_product_with_store!(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Product not found")
         |> push_navigate(to: ~p"/")}

      product ->
        # Verify the product belongs to the store with the given slug
        if product.store.slug == store_slug do
          {:ok, assign(socket, product: product)}
        else
          {:ok,
           socket
           |> put_flash(:error, "Product not found in this store")
           |> push_navigate(to: ~p"/#{store_slug}")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <div class="bg-white rounded-lg shadow-lg overflow-hidden">
          <div class="p-8">
            <div class="mb-6">
              <.link
                navigate={~p"/#{@product.store.slug}"}
                class="text-blue-600 hover:text-blue-800 text-sm"
              >
                ← Back to <%= @product.store.name %>
              </.link>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div>
                <h1 class="text-3xl font-bold text-gray-900 mb-4">
                  <%= @product.title %>
                </h1>
                
                <div class="text-2xl font-bold text-green-600 mb-6">
                  $<%= @product.price %>
                </div>

                <%= if @product.description do %>
                  <div class="text-gray-700 mb-6">
                    <h3 class="font-semibold mb-2">Description</h3>
                    <p class="leading-relaxed"><%= @product.description %></p>
                  </div>
                <% end %>

                <div class="mb-6">
                  <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                    <%= String.capitalize(@product.type) %> Product
                  </span>
                </div>

                <%= if @product.type == "digital" and @product.file_path do %>
                  <div class="mb-6 p-4 bg-gray-50 rounded-lg">
                    <h4 class="font-semibold text-gray-700 mb-2">Digital Product</h4>
                    <p class="text-sm text-gray-600">File: <%= @product.file_path %></p>
                  </div>
                <% end %>

                <div class="space-y-4">
                  <button 
                    phx-click="buy_now"
                    phx-disable-with="Creating checkout..."
                    class="btn btn-primary w-full"
                  >
                    Buy Now - $<%= @product.price %>
                  </button>
                  
                  <%= if @current_scope && @current_scope.user do %>
                    <button 
                      phx-click="add_to_cart"
                      phx-value-product_id={@product.id}
                      phx-value-store_id={@product.store_id}
                      phx-disable-with="Adding to cart..."
                      class="btn btn-outline w-full"
                    >
                      🛒 Add to Cart
                    </button>
                  <% end %>
                  
                  <%= if @current_scope && @current_scope.user && @current_scope.user.id == @product.store.user_id do %>
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/dashboard/products/#{@product.id}/edit"}
                        class="btn btn-secondary flex-1"
                      >
                        Edit Product
                      </.link>
                      
                      <button
                        phx-click="delete_product"
                        phx-confirm="Are you sure you want to delete this product?"
                        class="btn btn-error flex-1"
                      >
                        Delete
                      </button>
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="flex items-center justify-center">
                <div class="w-full h-64 bg-gray-200 rounded-lg flex items-center justify-center">
                  <div class="text-center text-gray-500">
                    <svg class="mx-auto h-12 w-12 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <p>Product Image</p>
                    <p class="text-sm">Image upload coming soon</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("delete_product", _params, socket) do
    case Products.delete_product(socket.assigns.product) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted successfully!")
         |> push_navigate(to: ~p"/#{socket.assigns.product.store.slug}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete product. Please try again.")}
    end
  end

  def handle_event("add_to_cart", %{"product_id" => product_id, "store_id" => store_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    
    case Shomp.Carts.get_or_create_cart(user_id, store_id) do
      {:ok, cart} ->
        case Shomp.Carts.add_to_cart(cart.id, product_id) do
          {:ok, _cart_item} ->
            # Update cart count
            cart_count = Shomp.Carts.list_user_carts(user_id)
            |> Enum.reduce(0, fn cart, acc -> 
              acc + Shomp.Carts.Cart.item_count(cart)
            end)
            
            socket = assign(socket, :cart_count, cart_count)
            
            # Push the updated count to the client
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

  def handle_event("buy_now", _params, socket) do
    # Redirect to checkout page
    checkout_url = ~p"/checkout/#{socket.assigns.product.id}"
    
    {:noreply,
     socket
     |> push_navigate(to: checkout_url)}
  end
end
