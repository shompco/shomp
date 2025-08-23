defmodule ShompWeb.ProductLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Products
  alias Shomp.Orders
  alias Shomp.Reviews
  alias Shomp.Stores
  alias Shomp.StoreCategories

  @impl true
  def mount(%{"store_slug" => store_slug, "id" => id}, _session, socket) do
    product = Products.get_product_with_store!(id)
    
    # Verify the product belongs to the store with the given slug
    if product.store.slug == store_slug do
      # Fetch reviews for this product
      reviews = Shomp.Reviews.get_product_reviews(id)
      
      {:ok, assign(socket, product: product, reviews: reviews, current_image: product.image_original, current_image_index: nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Product not found in this store")
       |> push_navigate(to: ~p"/#{store_slug}")}
    end
  end

  # New mount function for slug-based routing: /:store_slug/:category_slug/:product_slug
  def mount(%{"store_slug" => store_slug, "category_slug" => category_slug, "product_slug" => product_slug}, _session, socket) do
    # First, get the store by slug
    case Stores.get_store_by_slug(store_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}
      
      store ->
        # Get the custom category by slug within the store
        case StoreCategories.get_store_category_by_slug(store.store_id, category_slug) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Category not found")
             |> push_navigate(to: ~p"/#{store_slug}")}
          
          category ->
            # Get the product by slug within the store and category
            case Products.get_product_by_store_and_category_slug(store.store_id, category.id, product_slug) do
              nil ->
                {:ok,
                 socket
                 |> put_flash(:error, "Product not found")
                 |> push_navigate(to: ~p"/#{store_slug}")}
              
              product ->
                # Fetch reviews for this product
                reviews = Shomp.Reviews.get_product_reviews(product.id)
                
                {:ok, assign(socket, product: product, reviews: reviews, current_image: product.image_original, current_image_index: nil)}
            end
        end
    end
  end

  # New mount function for slug-based routing: /:store_slug/:product_slug
  # This could be either a product slug OR a category slug, so we need to check both
  def mount(%{"store_slug" => store_slug, "product_slug" => product_slug}, _session, socket) do
    # First, get the store by slug
    case Stores.get_store_by_slug(store_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}
      
      store ->
        # First check if this is a custom category slug
        case Shomp.StoreCategories.get_store_category_by_slug(store.store_id, product_slug) do
          category when not is_nil(category) ->
            # This is a category, redirect to the category page
            {:ok,
             socket
             |> push_navigate(to: ~p"/#{store_slug}/#{category.slug}")}
          
          nil ->
            # Not a category, try to find a product by this slug
            case Products.get_product_by_store_slug(store.store_id, product_slug) do
              nil ->
                {:ok,
                 socket
                 |> put_flash(:error, "Product not found")
                 |> push_navigate(to: ~p"/#{store_slug}")}
              
              product ->
                # Fetch reviews for this product
                reviews = Shomp.Reviews.get_product_reviews(product.id)
                
                IO.puts("=== PRODUCT DEBUG ===")
                IO.puts("Product ID: #{product.id}")
                IO.puts("Product additional_images: #{inspect(product.additional_images)}")
                IO.puts("Product image_original: #{inspect(product.image_original)}")
                IO.puts("=====================")
                
                {:ok, assign(socket, product: product, reviews: reviews, current_image: product.image_original, current_image_index: nil)}
            end
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
            <!-- Breadcrumb Navigation -->
            <div class="mb-6">
              <nav class="flex items-center space-x-2 text-sm text-gray-500">
                <.link
                  navigate={~p"/"}
                  class="hover:text-gray-700"
                >
                  Home
                </.link>
                <span>/</span>
                <.link
                  navigate={~p"/#{@product.store.slug}"}
                  class="hover:text-gray-700"
                >
                  <%= @product.store.name %>
                </.link>
                
                <%= if @product.custom_category do %>
                  <span>/</span>
                  <.link
                    navigate={~p"/#{@product.store.slug}/#{@product.custom_category.slug}"}
                    class="hover:text-gray-700"
                  >
                    <%= @product.custom_category.name %>
                  </.link>
                <% end %>
                
                <span>/</span>
                <span class="text-gray-900 font-medium"><%= @product.title %></span>
              </nav>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div>
                <h1 class="text-3xl font-bold text-gray-900 mb-4">
                  <%= @product.title %>
                </h1>
                
                <div class="text-2xl font-bold text-green-600 mb-6">
                  $<%= @product.price %>
                </div>

                <!-- Category Information -->
                <div class="mb-6 space-y-3">
                  <%= if @product.category do %>
                    <div class="flex items-center space-x-2">
                      <span class="text-sm text-gray-600">Platform Category:</span>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        <%= @product.category.name %>
                      </span>
                    </div>
                  <% end %>
                  
                  <%= if @product.custom_category do %>
                    <div class="flex items-center space-x-2">
                      <span class="text-sm text-gray-600">Store Category:</span>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        <%= @product.custom_category.name %>
                      </span>
                    </div>
                  <% end %>
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
                <%= if @product.image_original || (@product.additional_images && length(@product.additional_images) > 0) do %>
                  <!-- Main Product Image Carousel -->
                  <div class="relative">
                    <div class="relative h-80 overflow-hidden rounded-lg shadow-lg">
                      <!-- Main Image Display -->
                      <img 
                        src={@current_image || @product.image_original} 
                        alt={@product.title}
                        class="w-full h-full object-cover transition-opacity duration-500"
                        id="main-product-image"
                      />
                      
                      <!-- Previous/Next Navigation -->
                      <%= if @product.additional_images && length(@product.additional_images) > 0 do %>
                        <button 
                          phx-click="previous_image"
                          class="absolute left-4 top-1/2 transform -translate-y-1/2 bg-white bg-opacity-80 hover:bg-opacity-100 text-gray-800 p-2 rounded-full shadow-lg transition-all duration-200"
                          title="Previous image"
                        >
                          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                          </svg>
                        </button>
                        
                        <button 
                          phx-click="next_image"
                          class="absolute right-4 top-1/2 transform -translate-y-1/2 bg-white bg-opacity-80 hover:bg-opacity-100 text-gray-800 p-2 rounded-full shadow-lg transition-all duration-200"
                          title="Next image"
                        >
                          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                          </svg>
                        </button>
                      <% end %>
                      
                      <!-- Image Counter -->
                      <%= if @product.additional_images && length(@product.additional_images) > 0 do %>
                        <div class="absolute top-4 right-4 bg-black bg-opacity-50 text-white px-3 py-1 rounded-full text-sm">
                          <%= (@current_image_index || 0) + 1 %> / <%= length(@product.additional_images) + 1 %>
                        </div>
                      <% end %>
                    </div>
                    
                    <!-- Thumbnail Gallery -->
                    <div class="mt-4">
                      <div class="flex space-x-2 overflow-x-auto pb-2">
                        <!-- Primary Image Thumbnail -->
                        <button 
                          phx-click="show_image"
                          phx-value-index="primary"
                          class={"flex-shrink-0 w-20 h-20 rounded-lg overflow-hidden border-2 transition-all duration-200 #{if @current_image_index == nil, do: "border-blue-500", else: "border-gray-300 hover:border-gray-400"}"}
                        >
                          <img 
                            src={@product.image_thumb || @product.image_original} 
                            alt="Primary image"
                            class="w-full h-full object-cover"
                          />
                        </button>
                        
                        <!-- Additional Images Thumbnails -->
                        <%= for {image, index} <- Enum.with_index(@product.additional_images || []) do %>
                          <button 
                            phx-click="show_image"
                            phx-value-index={index}
                            class={"flex-shrink-0 w-20 h-20 rounded-lg overflow-hidden border-2 transition-all duration-200 #{if @current_image_index == index, do: "border-blue-500", else: "border-gray-300 hover:border-gray-400"}"}
                          >
                            <img 
                              src={image} 
                              alt="Product image #{index + 2}"
                              class="w-full h-full object-cover"
                            />
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <!-- No Images Placeholder -->
                  <div class="w-full h-80 bg-gray-200 rounded-lg flex items-center justify-center">
                    <div class="text-center">
                      <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <p class="text-gray-500">No images available</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
          
          <!-- Reviews Section -->
          <div class="border-t border-gray-200 pt-8">
            <div class="px-8">
              <div class="flex items-center justify-between mb-6">
                <div class="flex items-center space-x-4">
                  <h2 class="text-2xl font-bold text-gray-900">Customer Reviews</h2>
                  <%= if @reviews && length(@reviews) > 0 do %>
                    <.link
                      navigate={~p"/#{@product.store.slug}/products/#{@product.id}/reviews"}
                      class="text-blue-600 hover:text-blue-800 text-sm"
                    >
                      View All (<%= length(@reviews) %>)
                    </.link>
                  <% end %>
                </div>
                <%= if @current_scope && @current_scope.user && Shomp.Orders.user_purchased_product?(@current_scope.user.id, @product.id) do %>
                  <.link
                    navigate={~p"/#{@product.store.slug}/products/#{@product.id}/reviews/new"}
                    class="btn btn-primary"
                  >
                    Write a Review
                  </.link>
                <% end %>
              </div>
              
              <!-- Reviews Summary -->
              <%= if @reviews && length(@reviews) > 0 do %>
                <div class="bg-gray-50 rounded-lg p-6 mb-6">
                  <div class="flex items-center space-x-8">
                    <div class="text-center">
                      <div class="text-3xl font-bold text-gray-900">
                        <%= Float.round(Enum.reduce(@reviews, 0, fn review, acc -> acc + review.rating end) / length(@reviews), 1) %>
                      </div>
                      <div class="flex items-center justify-center space-x-1 mb-2">
                        <%= for rating <- 1..5 do %>
                          <svg class={"w-5 h-5 #{if rating <= Float.round(Enum.reduce(@reviews, 0, fn review, acc -> acc + review.rating end) / length(@reviews), 1), do: "text-yellow-400", else: "text-gray-300"}"} fill="currentColor" viewBox="0 0 20 20">
                            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                          </svg>
                        <% end %>
                      </div>
                      <div class="text-sm text-gray-600">out of 5</div>
                    </div>
                    <div class="flex-1">
                      <div class="text-lg font-medium text-gray-900 mb-2">
                        Based on <%= length(@reviews) %> review<%= if length(@reviews) != 1, do: "s" %>
                      </div>
                      <div class="space-y-2">
                        <%= for rating <- 5..1 do %>
                          <div class="flex items-center space-x-3">
                            <span class="text-sm text-gray-600 w-8"><%= rating %> stars</span>
                            <div class="flex-1 bg-gray-200 rounded-full h-2">
                              <div class="bg-yellow-400 h-2 rounded-full" style={"width: #{if length(@reviews) > 0, do: "#{Enum.count(Enum.filter(@reviews, fn review -> review.rating == rating end)) / length(@reviews) * 100}%", else: "0%"}"}></div>
                            </div>
                            <span class="text-sm text-gray-600 w-12 text-right"><%= Enum.count(Enum.filter(@reviews, fn review -> review.rating == rating end)) %></span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
              
              <%= if @reviews && length(@reviews) > 0 do %>
                <div class="space-y-6">
                  <%= for review <- @reviews do %>
                    <div class="border border-gray-200 rounded-lg p-6">
                      <div class="flex items-start justify-between mb-4">
                        <div class="flex items-center space-x-3">
                          <div class="flex items-center space-x-1">
                            <%= for rating <- 1..5 do %>
                              <svg class={"w-5 h-5 #{if rating <= review.rating, do: "text-yellow-400", else: "text-gray-300"}"} fill="currentColor" viewBox="0 0 20 20">
                                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                              </svg>
                            <% end %>
                          </div>
                          <span class="text-sm text-gray-600">
                            by <%= review.user.username %>
                          </span>
                          <%= if review.verified_purchase do %>
                            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              ✓ Verified Purchase
                            </span>
                          <% end %>
                        </div>
                        <span class="text-sm text-gray-500">
                          <%= Calendar.strftime(review.inserted_at, "%B %d, %Y") %>
                        </span>
                      </div>
                      
                      <div class="text-gray-700 mb-4">
                        <p class="leading-relaxed"><%= review.review_text %></p>
                      </div>
                      
                      <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-4">
                          <button 
                            phx-click="vote_helpful" 
                            phx-value-review_id={review.id}
                            phx-value-helpful={true}
                            class="flex items-center space-x-2 text-sm text-gray-600 hover:text-blue-600 transition-colors"
                          >
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5m-6-3a2 2 0 01-2-2V9a2 2 0 012-2h2" />
                            </svg>
                            <span>Helpful (<%= review.helpful_count %>)</span>
                          </button>
                          
                          <%= if @current_scope && @current_scope.user && @current_scope.user.id == review.user_id do %>
                            <div class="flex items-center space-x-2">
                              <.link
                                navigate={~p"/#{@product.store.slug}/products/#{@product.id}/reviews/#{review.id}/edit"}
                                class="text-sm text-blue-600 hover:text-blue-800 transition-colors"
                              >
                                Edit
                              </.link>
                              <span class="text-gray-300">|</span>
                              <button 
                                phx-click="delete_review" 
                                phx-value-review_id={review.id}
                                phx-confirm="Are you sure you want to delete this review?"
                                class="text-sm text-red-600 hover:text-red-800 transition-colors"
                              >
                                Delete
                              </button>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-12">
                  <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>
                  <h3 class="text-lg font-medium text-gray-900 mb-2">No reviews yet</h3>
                  <p class="text-gray-500 mb-4">Be the first to share your thoughts about this product!</p>
                  <%= if @current_scope && @current_scope.user && Shomp.Orders.user_purchased_product?(@current_scope.user.id, @product.id) do %>
                    <.link
                      navigate={~p"/#{@product.store.slug}/products/#{@product.id}/reviews/new"}
                      class="btn btn-primary"
                    >
                      Write the First Review
                    </.link>
                  <% end %>
                </div>
              <% end %>
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

  def handle_event("show_image", %{"index" => "primary"}, socket) do
    {:noreply, assign(socket, current_image: socket.assigns.product.image_original, current_image_index: nil)}
  end

  def handle_event("show_image", %{"index" => index}, socket) do
    index = String.to_integer(index)
    additional_images = socket.assigns.product.additional_images || []
    
    if index < length(additional_images) do
      image_url = Enum.at(additional_images, index)
      {:noreply, assign(socket, current_image: image_url, current_image_index: index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("next_image", _params, socket) do
    additional_images = socket.assigns.product.additional_images || []
    current_index = socket.assigns[:current_image_index]
    
    cond do
      current_index == nil ->
        # Currently showing primary image, go to first additional image
        if length(additional_images) > 0 do
          {:noreply, assign(socket, current_image: List.first(additional_images), current_image_index: 0)}
        else
          {:noreply, socket}
        end
      
      current_index < length(additional_images) - 1 ->
        # Go to next additional image
        next_index = current_index + 1
        next_image = Enum.at(additional_images, next_index)
        {:noreply, assign(socket, current_image: next_image, current_image_index: next_index)}
      
      current_index == length(additional_images) - 1 ->
        # Currently on last additional image, go back to primary
        {:noreply, assign(socket, current_image: socket.assigns.product.image_original, current_image_index: nil)}
      
      true ->
        {:noreply, socket}
    end
  end

  def handle_event("previous_image", _params, socket) do
    additional_images = socket.assigns.product.additional_images || []
    current_index = socket.assigns[:current_image_index]
    
    cond do
      current_index == nil ->
        # Currently showing primary image, go to last additional image
        if length(additional_images) > 0 do
          last_index = length(additional_images) - 1
          last_image = Enum.at(additional_images, last_index)
          {:noreply, assign(socket, current_image: last_image, current_image_index: last_index)}
        else
          {:noreply, socket}
        end
      
      current_index > 0 ->
        # Go to previous additional image
        prev_index = current_index - 1
        prev_image = Enum.at(additional_images, prev_index)
        {:noreply, assign(socket, current_image: prev_image, current_image_index: prev_index)}
      
      current_index == 0 ->
        # Currently on first additional image, go back to primary
        {:noreply, assign(socket, current_image: socket.assigns.product.image_original, current_image_index: nil)}
      
      true ->
        {:noreply, socket}
    end
  end

  def handle_event("vote_helpful", %{"review_id" => review_id, "helpful" => helpful}, socket) do
    user_id = socket.assigns.current_scope.user.id
    
    case Shomp.Reviews.get_or_create_review_vote(user_id, review_id, helpful == "true") do
      {:ok, _vote} ->
        # Update the review's helpful count and refresh reviews
        review = Shomp.Reviews.get_review!(review_id)
        Shomp.Reviews.update_review_helpful_count(review)
        
        reviews = Shomp.Reviews.get_product_reviews(socket.assigns.product.id)
        
        {:noreply, assign(socket, reviews: reviews)}
      
      {:ok, :removed} ->
        # Update the review's helpful count and refresh reviews
        review = Shomp.Reviews.get_review!(review_id)
        Shomp.Reviews.update_review_helpful_count(review)
        
        reviews = Shomp.Reviews.get_product_reviews(socket.assigns.product.id)
        
        {:noreply, 
         socket
         |> assign(reviews: reviews)
         |> put_flash(:info, "Vote removed!")}
      
      {:error, _changeset} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to submit vote.")}
    end
  end

  def handle_event("delete_review", %{"review_id" => review_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    review = Shomp.Reviews.get_review!(review_id)
    
    # Verify the review belongs to the current user
    if review.user_id != user_id do
      {:noreply, 
       socket
       |> put_flash(:error, "You can only delete your own reviews")}
    else
      case Shomp.Reviews.delete_review(review) do
        {:ok, _review} ->
          # Refresh reviews after deletion
          reviews = Shomp.Reviews.get_product_reviews(socket.assigns.product.id)
          
          {:noreply, 
           socket
           |> assign(reviews: reviews)
           |> put_flash(:info, "Review deleted successfully!")}
        
        {:error, _changeset} ->
          {:noreply, 
           socket
           |> put_flash(:error, "Failed to delete review")}
      end
    end
  end
end
