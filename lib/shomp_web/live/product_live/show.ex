defmodule ShompWeb.ProductLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Accounts
  alias Shomp.Products
  alias Shomp.Stores
  alias Shomp.StoreCategories

  # Helper function to calculate total price with donation
  defp calculate_total_price(product, donate) do
    if donate do
      donation_amount = Decimal.mult(product.price, Decimal.new("0.05"))
      total = Decimal.add(product.price, donation_amount)
      # Round to 2 decimal places and format nicely
      total
      |> Decimal.round(2)
      |> Decimal.to_string()
    else
      product.price
    end
  end

  @impl true
  def mount(%{"username" => username, "product_slug" => product_slug} = params, _session, socket) do
    # Get the user by username
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/")}

      user ->
        # Get the user's default store
        store = Shomp.Stores.get_user_default_store(user)
        if store do
          # Get the product by username and slug
          case Products.get_product_by_username_and_slug(username, product_slug) do
            nil ->
              {:ok,
               socket
               |> put_flash(:error, "Product not found")
               |> push_navigate(to: ~p"/#{username}")}

            product ->
              # Subscribe to product quantity changes
              if connected?(socket) do
                Phoenix.PubSub.subscribe(Shomp.PubSub, "product_quantity:#{product.id}")
              end

              # Fetch reviews for this product
              reviews = Shomp.Reviews.get_product_reviews(product.id)
              referrer = params["referrer"] || "store"

              {:ok, assign(socket, product: product, reviews: reviews, current_image: product.image_original, current_image_index: nil, donate: true, referrer: referrer)}
          end
        else
          {:ok,
           socket
           |> put_flash(:error, "Store not found")
           |> push_navigate(to: ~p"/")}
        end
    end
  end

  def mount(%{"store_slug" => store_slug, "id" => id} = params, _session, socket) do
    product = Products.get_product_with_store!(id)

    # Subscribe to product quantity changes
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Shomp.PubSub, "product_quantity:#{id}")
    end

    # Verify the product belongs to the store with the given slug
    if product.store.slug == store_slug do
      # Fetch reviews for this product
      reviews = Shomp.Reviews.get_product_reviews(id)
      referrer = params["referrer"] || "store"

      {:ok, assign(socket, product: product, reviews: reviews, current_image: product.image_original, current_image_index: nil, donate: true, referrer: referrer)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Product not found in this store")
       |> push_navigate(to: ~p"/stores/#{store_slug}")}
    end
  end

  # New mount function for slug-based routing: /:store_slug/:category_slug/:product_slug
  def mount(%{"store_slug" => store_slug, "category_slug" => category_slug, "product_slug" => product_slug} = params, _session, socket) do
    # First, get the store by slug
    case Stores.get_store_by_slug(store_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}

      store ->
        # Subscribe to product quantity changes
        if connected?(socket) do
          # We'll get the product ID later when we find the product
        end

        # Get the custom category by slug within the store
        case StoreCategories.get_store_category_by_slug(store.store_id, category_slug) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Category not found")
             |> push_navigate(to: ~p"/stores/#{store_slug}")}

          category ->
            # Get the product by slug within the store and category
            case Products.get_product_by_store_and_category_slug(store.store_id, category.id, product_slug) do
              nil ->
                {:ok,
                 socket
                 |> put_flash(:error, "Product not found")
                 |> push_navigate(to: ~p"/stores/#{store_slug}")}

              product ->
                # Subscribe to product quantity changes
                if connected?(socket) do
                  Phoenix.PubSub.subscribe(Shomp.PubSub, "product_quantity:#{product.id}")
                end

                # Fetch reviews for this product
                reviews = Shomp.Reviews.get_product_reviews(product.id)

                referrer = params["referrer"] || "store_category"
                {:ok, assign(socket, product: product, reviews: reviews, current_image: product.image_original, current_image_index: nil, donate: true, referrer: referrer)}
            end
        end
    end
  end

  # New mount function for slug-based routing: /:store_slug/products/:product_slug
  # This handles products in the default "products" category
  def mount(%{"store_slug" => store_slug, "product_slug" => product_slug} = params, _session, socket) do
    # First, get the store by slug
    case Stores.get_store_by_slug(store_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}

      store ->
        # Find product by slug in this store
        case Products.get_product_by_store_slug(store.store_id, product_slug) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Product not found")
             |> push_navigate(to: ~p"/stores/#{store_slug}")}

          product ->
            # Subscribe to product quantity changes
            if connected?(socket) do
              Phoenix.PubSub.subscribe(Shomp.PubSub, "product_quantity:#{product.id}")
            end

            # Fetch reviews for this product
            reviews = Shomp.Reviews.get_product_reviews(product.id)

            IO.puts("=== PRODUCT DEBUG ===")
            IO.puts("Product ID: #{product.id}")
            IO.puts("Product additional_images: #{inspect(product.additional_images)}")
            IO.puts("Product image_original: #{inspect(product.image_original)}")
            IO.puts("=====================")

            referrer = params["referrer"] || "store"
            {:ok, assign(socket, product: product, reviews: reviews, current_image: product.image_original, current_image_index: nil, donate: true, referrer: referrer)}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Full Width Product Page -->
    <div class="w-full min-h-screen bg-base-100">
      <!-- Main Product Content -->
      <div class="w-full px-4 sm:px-6 lg:px-8 py-6">
        <!-- Back Button -->
        <div class="mb-4">
          <button
            onclick="history.back()"
            class="inline-flex items-center text-sm text-primary hover:text-primary-focus transition-colors duration-200"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            <%= case Map.get(assigns, :referrer, "store") do %>
              <% "category" -> %>Back to All Categories
              <% "store_category" -> %>Back to <%= @product.custom_category.name %>
              <% _ -> %>Back to All Stores
            <% end %>
          </button>
        </div>

        <!-- Breadcrumb Navigation -->
        <div class="mb-6">
          <nav class="flex items-center space-x-2 text-sm text-base-content/70">
            <.link
              navigate={~p"/stores"}
              class="hover:text-base-content transition-colors"
            >
              Stores
            </.link>
            <span>/</span>
            <.link
              navigate={~p"/#{@product.store.user.username}"}
              class="hover:text-base-content transition-colors"
            >
              <%= @product.store.user.username %>
            </.link>

            <%= if @product.custom_category && Map.has_key?(@product.custom_category, :slug) && @product.custom_category.slug do %>
              <span>/</span>
              <.link
                navigate={~p"/stores/#{@product.store.slug}/#{@product.custom_category.slug}"}
                class="hover:text-base-content transition-colors"
              >
                <%= @product.custom_category.name %>
              </.link>
            <% end %>

            <span>/</span>
            <span class="text-base-content font-medium"><%= @product.title %></span>
          </nav>
        </div>

        <div class="grid grid-cols-1 xl:grid-cols-2 gap-8 xl:gap-16">
          <!-- Left Column: Large Image Gallery -->
          <div class="space-y-8">
            <!-- Main Product Image -->
            <%= if has_valid_image(@current_image) || has_valid_image(@product.image_original) do %>
              <div class="relative">
                <div class="relative aspect-square overflow-hidden rounded-2xl shadow-2xl bg-base-200">
                  <img
                    src={@current_image || @product.image_original}
                    alt={@product.title}
                    class="w-full h-full object-cover transition-opacity duration-500"
                    id="main-product-image"
                  />

                  <%= if @product.quantity == 0 && @product.type == "physical" do %>
                    <div class="absolute bottom-4 right-4 bg-orange-200 text-orange-800 px-4 py-2 rounded-full text-lg font-bold shadow-lg">
                      SOLD OUT
                    </div>
                  <% end %>
                </div>

                <!-- Navigation Buttons - Below Image -->
                <%= if @product.additional_images && length(@product.additional_images) > 0 do %>
                  <div class="flex justify-center space-x-4 mt-6">
                    <button
                      phx-click="previous_image"
                      class="bg-base-300 hover:bg-base-300/80 text-base-content p-3 rounded-full shadow-lg transition-all duration-200"
                      title="Previous image"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                      </svg>
                    </button>

                    <button
                      phx-click="next_image"
                      class="bg-base-300 hover:bg-base-300/80 text-base-content p-3 rounded-full shadow-lg transition-all duration-200"
                      title="Next image"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                      </svg>
                    </button>
                  </div>
                <% end %>
              </div>

              <!-- Thumbnail Gallery -->
              <%= if @product.additional_images && length(@product.additional_images) > 0 do %>
                <div class="space-y-4">
                  <h3 class="text-lg font-semibold text-base-content">Product Images</h3>
                  <div class="flex space-x-3 overflow-x-auto pb-2">
                    <!-- Primary Image Thumbnail -->
                    <%= if has_valid_image(@product.image_thumb) || has_valid_image(@product.image_original) do %>
                      <button
                        phx-click="show_image"
                        phx-value-index="primary"
                        class={"flex-shrink-0 w-24 h-24 rounded-xl overflow-hidden border-2 transition-all duration-200 #{if @current_image_index == nil, do: "border-primary ring-2 ring-primary/20", else: "border-base-300 hover:border-base-400"}"}
                      >
                        <img
                          src={@product.image_thumb || @product.image_original}
                          alt="Primary image"
                          class="w-full h-full object-cover"
                        />
                      </button>
                    <% end %>

                    <!-- Additional Images Thumbnails -->
                    <%= for {image, index} <- Enum.with_index(@product.additional_images || []) do %>
                      <button
                        phx-click="show_image"
                        phx-value-index={index}
                        class={"flex-shrink-0 w-24 h-24 rounded-xl overflow-hidden border-2 transition-all duration-200 #{if @current_image_index == index, do: "border-primary ring-2 ring-primary/20", else: "border-base-300 hover:border-base-400"}"}
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
              <% end %>
            <% else %>
              <!-- No Image Placeholder -->
              <div class="aspect-square bg-base-300 rounded-2xl flex items-center justify-center">
                <div class="text-center">
                  <svg class="w-24 h-24 text-base-content/50 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <p class="text-base-content/70 text-lg">No image available</p>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Right Column: Product Information -->
          <div class="space-y-8">
            <!-- Product Header -->
            <div class="space-y-4">
              <h1 class="text-4xl lg:text-5xl font-bold text-base-content leading-tight">
                <%= @product.title %>
              </h1>


              <div class="text-3xl lg:text-4xl font-bold text-primary">
                $<%= @product.price %>
              </div>

              <%= if @product.type == "physical" do %>
                <div class="text-lg text-base-content/70">
                  <%= if @product.quantity > 0 do %>
                    <span class="text-green-600 font-medium">
                      <%= @product.quantity %> available
                    </span>
                  <% else %>
                    <span class="text-orange-600 font-medium">
                      Out of stock
                    </span>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Category Information -->
            <div class="space-y-4">
              <%= if @product.category do %>
                <div class="flex items-center space-x-3">
                  <span class="text-sm font-medium text-base-content/70">Platform:</span>
                  <span class="inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium bg-primary/10 text-primary border border-primary/20">
                    <%= @product.category.name %>
                  </span>
                </div>
              <% end %>

              <%= if @product.custom_category && Map.has_key?(@product.custom_category, :name) do %>
                <div class="flex items-center space-x-3">
                  <span class="text-sm font-medium text-base-content/70">Category:</span>
                  <span class="inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium bg-secondary/10 text-secondary border border-secondary/20">
                    <%= @product.custom_category.name %>
                  </span>
                </div>
              <% end %>

              <div class="flex items-center space-x-3">
                <span class="text-sm font-medium text-base-content/70">Type:</span>
                <span class="inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium bg-accent/10 text-accent border border-accent/20">
                  <%= String.capitalize(@product.type) %> Product
                </span>
              </div>
            </div>

            <!-- Description -->
            <%= if @product.description do %>
              <div class="space-y-3">
                <h3 class="text-xl font-semibold text-base-content">Description</h3>
                <div class="prose prose-base-content max-w-none">
                  <p class="text-base-content/80 leading-relaxed text-lg"><%= @product.description %></p>
                </div>
              </div>
            <% end %>

            <!-- Digital Product Info -->
            <%= if @product.type == "digital" and @product.file_path do %>
              <div class="p-6 bg-primary/5 rounded-2xl border border-primary/20">
                <div class="flex items-center space-x-3">
                  <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <h4 class="font-semibold text-primary">Digital Product</h4>
                </div>
                <p class="text-primary/80 mt-2">File: <%= @product.file_path %></p>
              </div>
            <% end %>

            <!-- Donation Checkbox -->
            <div class="pt-6 pb-4">
              <div class="flex items-center space-x-3 p-4 bg-base-200 rounded-lg">
                <input type="checkbox"
                       id="donate_checkbox"
                       name="donate"
                       checked={@donate}
                       phx-click="toggle_donation"
                       class="checkbox checkbox-primary" />
                <label for="donate_checkbox" class="text-base-content/80 cursor-pointer">
                  Add 5% donation to Shomp
                </label>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="space-y-4">
              <%= if @product.quantity == 0 && @product.type == "physical" do %>
                <button
                  disabled
                  title="This product is sold out"
                  class="w-full bg-gray-400 text-gray-600 font-bold py-4 px-8 rounded-2xl text-lg shadow-lg cursor-not-allowed opacity-60"
                >
                  SOLD OUT - $<%= calculate_total_price(@product, @donate) %>
                </button>
              <% else %>
                <button
                  phx-click="buy_now"
                  phx-disable-with="Creating checkout..."
                  class="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-4 px-8 rounded-2xl text-lg shadow-lg hover:shadow-xl transition-all duration-200 transform hover:-translate-y-1"
                >
                  Buy Now - $<%= calculate_total_price(@product, @donate) %>
                </button>
              <% end %>

              <%= if @current_scope && @current_scope.user do %>
                <%= if @product.quantity == 0 && @product.type == "physical" do %>
                  <button
                    disabled
                    title="This product is sold out"
                    class="w-full bg-gray-300 text-gray-500 font-semibold py-3 px-6 rounded-2xl shadow-lg cursor-not-allowed opacity-60"
                  >
                    🛒 Add to Cart (Sold Out)
                  </button>
                <% else %>
                  <button
                    phx-click="add_to_cart"
                    phx-value-product_id={@product.id}
                    phx-value-store_id={@product.store_id}
                    phx-disable-with="Adding to cart..."
                    class="w-full bg-base-300 hover:bg-base-400 text-base-content font-semibold py-3 px-6 rounded-2xl shadow-lg hover:shadow-xl transition-all duration-200"
                  >
                    🛒 Add to Cart
                  </button>
                <% end %>
              <% end %>

              <%= if @current_scope && @current_scope.user && @current_scope.user.id == @product.store.user_id do %>
                <div class="pt-4 border-t border-base-300">
                  <.link
                    navigate={~p"/dashboard/products/#{@product.id}/edit"}
                    class="w-full bg-secondary hover:bg-secondary-focus text-secondary-content font-semibold py-3 px-6 rounded-2xl shadow-lg hover:shadow-xl transition-all duration-200 text-center block"
                  >
                    Edit Product
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:quantity_changed, updated_product}, socket) do
    # Update the product in socket assigns with new quantity
    IO.puts("🔄 Received quantity change via PubSub: product #{updated_product.id} quantity = #{updated_product.quantity}")
    {:noreply, assign(socket, product: updated_product)}
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

  def handle_event("toggle_donation", _params, socket) do
    {:noreply, assign(socket, :donate, !socket.assigns.donate)}
  end

  def handle_event("buy_now", _params, socket) do
    # Redirect to custom Stripe Elements checkout
    product = socket.assigns.product
    donate = socket.assigns.donate
    store_slug = product.store.slug

    # Pass donation preference and referrer as URL parameters
    {:noreply, push_navigate(socket, to: ~p"/checkout/single/#{product.id}?donate=#{donate}&from=store&store=#{store_slug}")}
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

  # Helper function to check if an image URL is valid and not empty
  defp has_valid_image(image_url) do
    image_url && image_url != "" && String.trim(image_url) != ""
  end
end
