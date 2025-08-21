defmodule ShompWeb.ProductLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Products

  @impl true
  def mount(%{"store_slug" => store_slug, "id" => id}, _session, socket) do
    product = Products.get_product_with_store!(id)
    
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
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Product Images Section -->
              <div class="space-y-4">
                <!-- DEBUG: Image Paths (Remove this after debugging) -->
                <div class="p-4 bg-yellow-100 border border-yellow-300 rounded-lg">
                  <h4 class="font-semibold text-yellow-800 mb-2">🔍 DEBUG: Image Paths</h4>
                  <div class="text-xs text-yellow-700 space-y-1">
                    <div><strong>Original:</strong> <%= @product.image_original || "nil" %></div>
                    <div><strong>Thumb:</strong> <%= @product.image_thumb || "nil" %></div>
                    <div><strong>Medium:</strong> <%= @product.image_medium || "nil" %></div>
                    <div><strong>Large:</strong> <%= @product.image_large || "nil" %></div>
                    <div><strong>Extra Large:</strong> <%= @product.image_extra_large || "nil" %></div>
                    <div><strong>Ultra:</strong> <%= @product.image_ultra || "nil" %></div>
                    <div><strong>Additional Images:</strong> <%= inspect(@product.additional_images) %></div>
                    <div><strong>Primary Index:</strong> <%= @product.primary_image_index %></div>
                  </div>
                </div>
                
                <%= if @product.image_original do %>
                  <!-- Main Product Image -->
                  <div class="relative">
                    <img 
                      src={@product.image_original} 
                      alt={@product.title}
                      class="w-full h-80 object-cover rounded-lg shadow-lg"
                      id="main-product-image"
                    />
                    
                    <!-- Image Navigation Overlay -->
                    <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2 flex space-x-2">
                      <%= if @product.image_thumb do %>
                        <button 
                          phx-click="switch_image" 
                          phx-value-size="thumb"
                          class="w-3 h-3 bg-white rounded-full opacity-60 hover:opacity-100 transition-opacity"
                        ></button>
                      <% end %>
                      <%= if @product.image_medium do %>
                        <button 
                          phx-click="switch_image" 
                          phx-value-size="medium"
                          class="w-3 h-3 bg-white rounded-full opacity-60 hover:opacity-100 transition-opacity"
                        ></button>
                      <% end %>
                      <%= if @product.image_large do %>
                        <button 
                          phx-click="switch_image" 
                          phx-value-size="large"
                          class="w-3 h-3 bg-white rounded-full opacity-60 hover:opacity-100 transition-opacity"
                        ></button>
                      <% end %>
                      <%= if @product.image_extra_large do %>
                        <button 
                          phx-click="switch_image" 
                          phx-value-size="extra_large"
                          class="w-3 h-3 bg-white rounded-full opacity-60 hover:opacity-100 transition-opacity"
                        ></button>
                      <% end %>
                      <%= if @product.image_ultra do %>
                        <button 
                          phx-click="switch_image" 
                          phx-value-size="ultra"
                          class="w-3 h-3 bg-white rounded-full opacity-60 hover:opacity-100 transition-opacity"
                        ></button>
                      <% end %>
                    </div>
                  </div>
                  
                  <!-- Thumbnail Gallery -->
                  <div class="grid grid-cols-5 gap-2">
                    <%= if @product.image_thumb do %>
                      <button 
                        phx-click="switch_image" 
                        phx-value-size="thumb"
                        class="w-16 h-16 rounded-lg overflow-hidden border-2 border-transparent hover:border-blue-500 transition-colors"
                      >
                        <img 
                          src={@product.image_thumb} 
                          alt="Thumbnail"
                          class="w-full h-full object-cover"
                        />
                      </button>
                    <% end %>
                    <%= if @product.image_medium do %>
                      <button 
                        phx-click="switch_image" 
                        phx-value-size="medium"
                        class="w-16 h-16 rounded-lg overflow-hidden border-2 border-transparent hover:border-blue-500 transition-colors"
                      >
                        <img 
                          src={@product.image_medium} 
                          alt="Medium"
                          class="w-full h-full object-cover"
                        />
                      </button>
                    <% end %>
                    <%= if @product.image_large do %>
                      <button 
                        phx-click="switch_image" 
                        phx-value-size="large"
                        class="w-16 h-16 rounded-lg overflow-hidden border-2 border-transparent hover:border-blue-500 transition-colors"
                      >
                        <img 
                          src={@product.image_large} 
                          alt="Large"
                          class="w-full h-16 object-cover"
                        />
                      </button>
                    <% end %>
                    <%= if @product.image_extra_large do %>
                      <button 
                        phx-click="switch_image" 
                        phx-value-size="extra_large"
                        class="w-16 h-16 rounded-lg overflow-hidden border-2 border-transparent hover:border-blue-500 transition-colors"
                      >
                        <img 
                          src={@product.image_extra_large} 
                          alt="Extra Large"
                          class="w-full h-16 object-cover"
                        />
                      </button>
                    <% end %>
                    <%= if @product.image_ultra do %>
                      <button 
                        phx-click="switch_image" 
                        phx-value-size="ultra"
                        class="w-16 h-16 rounded-lg overflow-hidden border-2 border-transparent hover:border-blue-500 transition-colors"
                      >
                        <img 
                          src={@product.image_ultra} 
                          alt="Ultra"
                          class="w-full h-16 object-cover"
                        />
                      </button>
                    <% end %>
                  </div>
                <% else %>
                  <!-- No Image Placeholder -->
                  <div class="w-full h-80 bg-gray-200 rounded-lg flex items-center justify-center">
                    <div class="text-center text-gray-500">
                      <svg class="mx-auto h-12 w-12 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <p>No Product Image</p>
                      <p class="text-sm">Add images when editing the product</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
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
          
          {:error, :item_already_in_cart} ->
            {:noreply, 
             socket
             |> put_flash(:info, "This product is already in your cart!")}
          
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

  def handle_event("switch_image", %{"size" => size}, socket) do
    # Get the image path for the selected size
    image_path = case size do
      "thumb" -> socket.assigns.product.image_thumb
      "medium" -> socket.assigns.product.image_medium
      "large" -> socket.assigns.product.image_large
      "extra_large" -> socket.assigns.product.image_extra_large
      "ultra" -> socket.assigns.product.image_ultra
      _ -> socket.assigns.product.image_original
    end
    
    # Push the image switch event to the client
    {:noreply, push_event(socket, "switch-main-image", %{image_path: image_path})}
  end
end
