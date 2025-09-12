defmodule ShompWeb.StoreLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Stores
  alias Shomp.StoreCategories

  # Mount function for category listing page: /:store_slug/:category_slug
  def mount(%{"store_slug" => store_slug, "category_slug" => category_slug}, _session, socket) do
    case Stores.get_store_by_slug_with_user(store_slug) do
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
             |> push_navigate(to: ~p"/stores/#{store_slug}")}

          category ->
            # Load products in this specific category
            products = Shomp.Products.get_products_by_custom_category(category.id)

            {:ok, assign(socket,
              store: store,
              category: category,
              products: products,
              custom_categories: [],
              products_by_category: %{},
              show_category_page: true
            )}
        end
    end
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # Redirect to home if slug is empty
    if slug == "" or slug == nil do
      {:ok, socket |> push_navigate(to: ~p"/")}
    else
      case Stores.get_store_by_slug_with_user(slug) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, "Store not found")
           |> push_navigate(to: ~p"/")}

        store ->
          # Load products for this store using the immutable store_id
          products = Shomp.Products.list_products_by_store(store.store_id)

          # Load custom categories for this store
          custom_categories = Shomp.StoreCategories.list_store_categories_with_counts(store.store_id)

          # Group products by custom category
          products_by_category = Enum.group_by(products, fn product ->
            if product.custom_category_id do
              Enum.find(custom_categories, fn cat -> cat.id == product.custom_category_id end)
            else
              nil
            end
          end)

          {:ok, assign(socket,
            store: store,
            products: products,
            custom_categories: custom_categories,
            products_by_category: products_by_category
          )}
      end
    end
  end



  @impl true
  def render(assigns) do
    ~H"""
    <%= if assigns[:show_category_page] do %>
      <!-- Category Listing Page -->
      <div class="w-full px-4 py-8">
        <div class="mb-8">
          <nav class="text-xs breadcrumbs mb-6">
            <ul>
              <li><a href="/" class="link link-hover">Home</a></li>
              <li><a href="/stores" class="link link-hover">Stores</a></li>
              <li><a href={"/stores/#{@store.slug}"} class="link link-hover"><%= @store.name %></a></li>
              <li><%= @category.name %></li>
            </ul>
          </nav>

          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            <%= @category.name %>
          </h1>

          <%= if @category.description do %>
            <p class="text-xl text-gray-600 mb-8">
              <%= @category.description %>
            </p>
          <% end %>

          <div class="text-sm text-gray-500 mb-8">
            <%= length(@products) %> product<%= if length(@products) != 1, do: "s" %> in this category
          </div>
        </div>

        <!-- Products Grid -->
        <%= if Enum.empty?(@products) do %>
          <div class="text-center py-12">
            <div class="text-gray-500 text-lg mb-4">
              No products in this category yet.
            </div>
            <%= if @current_scope && @current_scope.user && @current_scope.user.id == @store.user_id do %>
              <.link
                navigate={~p"/dashboard/products/new?store_id=#{@store.store_id}"}
                class="btn btn-primary"
              >
                Add Products to This Category
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 gap-6">
            <%= for product <- @products do %>
              <%= render_product_card(assigns, product) %>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <!-- Store Home Page - FULL VIEWPORT -->
      <div class="w-screen min-h-screen bg-base-100">
        <!-- Ultra Thin Header Section -->
        <div class="relative w-screen h-12 bg-gradient-to-r from-primary/10 to-secondary/10 border-b border-base-300">
          <div class="relative z-10 flex items-center justify-between h-full px-4">
            <div class="flex items-center space-x-3">
              <h1 class="text-lg font-semibold text-primary">
                <%= @store.name %>
              </h1>
              <span class="text-sm text-base-content/60">
                <%= length(@products) %> products
              </span>
              <span class="text-sm text-base-content/60">
                <%= length(@custom_categories) %> categories
              </span>
            </div>
            <div class="flex items-center space-x-3">
              <div class="text-sm text-base-content/70">
                <%= if @store.description do %>
                  <%= String.slice(@store.description, 0, 60) %><%= if String.length(@store.description) > 60, do: "...", else: "" %>
                <% end %>
              </div>
              <!-- Add Product Button for Store Owner -->
              <%= if @current_scope && @current_scope.user && @current_scope.user.id == @store.user_id do %>
              <.link
                navigate={~p"/dashboard/products/new?store_id=#{@store.store_id}"}
                class="bg-primary hover:bg-primary-focus text-primary-content text-xs font-semibold px-2 py-1 rounded transition-all duration-200"
              >
                + Add
              </.link>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Breadcrumbs -->
        <div class="w-full bg-base-100">
          <div class="px-4 py-2">
            <nav class="text-xs breadcrumbs">
              <ul>
                <li><a href="/" class="link link-hover">Home</a></li>
                <li><a href="/stores" class="link link-hover">Stores</a></li>
                <li><%= @store.name %></li>
              </ul>
            </nav>
          </div>
        </div>

        <!-- Main Content - FULL WIDTH Products -->
        <div class="w-screen bg-base-100">
          <%= if Enum.empty?(@products) do %>
            <!-- Empty State -->
            <div class="w-screen text-center py-32">
              <div class="max-w-2xl mx-auto">
                <div class="w-32 h-32 bg-base-300 rounded-full flex items-center justify-center mx-auto mb-8">
                  <svg class="w-16 h-16 text-base-content/50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                  </svg>
                </div>
                <h3 class="text-4xl font-bold text-base-content mb-4">Store Coming Soon</h3>
                <p class="text-xl text-base-content/70 mb-12">This store is currently being set up. Products will be available soon!</p>

                <%= if @current_scope && @current_scope.user && @current_scope.user.id == @store.user_id do %>
                  <div class="space-y-6">
                    <.link
                      navigate={~p"/dashboard/store"}
                      class="btn btn-primary btn-lg text-lg px-8 py-4"
                    >
                      Manage Store
                    </.link>

                    <.link
                      navigate={~p"/dashboard/products/new?store_id=#{@store.store_id}"}
                      class="btn btn-secondary btn-lg text-lg px-8 py-4 ml-4"
                    >
                      Add Product
                    </.link>
                  </div>
                <% else %>
                  <div class="text-base-content/70 text-lg">
                    <p>Store owner: <%= @store.user.username || "Creator" %></p>
                  </div>
                <% end %>
              </div>
            </div>
          <% else %>
            <!-- Products by Category - FULL WIDTH -->
            <div class="w-screen space-y-8 py-8">
              <!-- Uncategorized Products -->
              <%= if Map.has_key?(@products_by_category, nil) and length(Map.get(@products_by_category, nil)) > 0 do %>
                <div class="w-screen px-4">
                  <div class="text-left mb-4">
                    <h2 class="text-lg font-semibold text-base-content mb-1">All Products</h2>
                    <p class="text-sm text-base-content/70">Complete collection</p>
                  </div>
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 md:gap-6">
                    <%= for {product, index} <- Enum.with_index(Map.get(@products_by_category, nil)) do %>
                      <a
                        href={get_product_url(product) <> "?referrer=store"}
                        class="group relative aspect-square overflow-hidden rounded-lg bg-base-200 hover:shadow-2xl transition-all duration-500 hover:scale-105"
                        style={"animation-delay: #{index * 50}ms"}
                      >
                        <!-- Product Image -->
                        <%= if get_product_image(product) do %>
                          <img
                            src={get_product_image(product)}
                            alt={product.title}
                            class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                            loading="lazy"
                          />
                        <% else %>
                          <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-base-200 to-base-300">
                            <div class="text-center p-4">
                              <div class="text-4xl mb-2">
                                <%= case product.type do %>
                                  <% "digital" -> %>💻
                                  <% "physical" -> %>📦
                                  <% _ -> %>🎨
                                <% end %>
                              </div>
                              <p class="text-xs text-base-content/60">No Image</p>
                            </div>
                          </div>
                        <% end %>

                        <!-- Overlay with Product Details -->
                        <div class="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                          <div class="absolute bottom-0 left-0 right-0 p-3 text-white">
                            <h3 class="font-bold text-sm mb-2 line-clamp-2 group-hover:text-primary transition-colors duration-300">
                              <%= product.title %>
                            </h3>
                            <div class="flex items-center justify-between text-xs mb-2">
                              <span class="font-semibold text-primary-200 text-lg">
                                $<%= product.price %>
                              </span>
                              <span class="text-white/80">
                                <%= @store.name %>
                              </span>
                            </div>
                            <div class="flex items-center justify-between">
                              <span class="text-xs text-white/70">
                                <%= case product.type do %>
                                  <% "digital" -> %>💻 Digital
                                  <% "physical" -> %>📦 Physical
                                  <% _ -> %>🎨 Product
                                <% end %>
                              </span>
                              <div class="flex items-center text-xs text-white/70">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.293l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clip-rule="evenodd" />
                                </svg>
                                View
                              </div>
                            </div>
                            <%= if product.quantity == 0 && product.type == "physical" do %>
                              <div class="mt-2 text-center">
                                <span class="text-xs text-red-300 font-medium bg-red-900/20 px-2 py-1 rounded">SOLD OUT</span>
                              </div>
                            <% end %>
                          </div>
                        </div>

                        <!-- Hover Effect Overlay -->
                        <div class="absolute inset-0 bg-gradient-to-br from-white/20 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>
                      </a>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Products by Custom Category -->
              <%= for category <- @custom_categories do %>
                <%= if Map.has_key?(@products_by_category, category) and length(Map.get(@products_by_category, category)) > 0 do %>
                  <div class="w-screen px-4">
                    <div class="text-left mb-4">
                      <h2 class="text-lg font-semibold text-base-content mb-1">
                        <%= category.name %>
                      </h2>
                      <%= if category.description do %>
                        <p class="text-sm text-base-content/70 mb-2 max-w-4xl"><%= String.slice(category.description, 0, 80) %><%= if String.length(category.description) > 80, do: "...", else: "" %></p>
                      <% end %>
                      <div class="flex items-center space-x-4">
                        <span class="text-xs text-base-content/60">
                          <%= length(Map.get(@products_by_category, category)) %> product<%= if length(Map.get(@products_by_category, category)) != 1, do: "s" %>
                        </span>
                        <.link
                          navigate={~p"/stores/#{@store.slug}/#{category.slug}"}
                          class="text-primary hover:text-primary-focus font-semibold text-xs hover:underline transition-colors"
                        >
                          View All →
                        </.link>
                      </div>
                    </div>
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 md:gap-6">
                      <%= for {product, index} <- Enum.with_index(Enum.take(Map.get(@products_by_category, category), 6)) do %>
                        <a
                          href={get_product_url(product) <> "?referrer=store"}
                          class="group relative aspect-square overflow-hidden rounded-lg bg-base-200 hover:shadow-2xl transition-all duration-500 hover:scale-105"
                          style={"animation-delay: #{index * 50}ms"}
                        >
                          <!-- Product Image -->
                          <%= if get_product_image(product) do %>
                            <img
                              src={get_product_image(product)}
                              alt={product.title}
                              class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                              loading="lazy"
                            />
                          <% else %>
                            <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-base-200 to-base-300">
                              <div class="text-center p-4">
                                <div class="text-4xl mb-2">
                                  <%= case product.type do %>
                                    <% "digital" -> %>💻
                                    <% "physical" -> %>📦
                                    <% _ -> %>🎨
                                  <% end %>
                                </div>
                                <p class="text-xs text-base-content/60">No Image</p>
                              </div>
                            </div>
                          <% end %>

                          <!-- Overlay with Product Details -->
                          <div class="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                            <div class="absolute bottom-0 left-0 right-0 p-3 text-white">
                              <h3 class="font-bold text-sm mb-2 line-clamp-2 group-hover:text-primary transition-colors duration-300">
                                <%= product.title %>
                              </h3>
                              <div class="flex items-center justify-between text-xs mb-2">
                                <span class="font-semibold text-primary-200 text-lg">
                                  $<%= product.price %>
                                </span>
                                <span class="text-white/80">
                                  <%= @store.name %>
                                </span>
                              </div>
                              <div class="flex items-center justify-between">
                                <span class="text-xs text-white/70">
                                  <%= case product.type do %>
                                    <% "digital" -> %>💻 Digital
                                    <% "physical" -> %>📦 Physical
                                    <% _ -> %>🎨 Product
                                  <% end %>
                                </span>
                                <div class="flex items-center text-xs text-white/70">
                                  <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.293l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clip-rule="evenodd" />
                                  </svg>
                                  View
                                </div>
                              </div>
                              <%= if product.quantity == 0 && product.type == "physical" do %>
                                <div class="mt-2 text-center">
                                  <span class="text-xs text-red-300 font-medium bg-red-900/20 px-2 py-1 rounded">SOLD OUT</span>
                                </div>
                              <% end %>
                            </div>
                          </div>

                          <!-- Hover Effect Overlay -->
                          <div class="absolute inset-0 bg-gradient-to-br from-white/20 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>
                        </a>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_product_card(assigns, product) do
    assigns = assign(assigns, :product, product)

    ~H"""
    <.link
      navigate={
        if @product.slug do
          if Map.has_key?(@product, :custom_category) &&
             @product.custom_category &&
             Map.has_key?(@product.custom_category, :slug) &&
             @product.custom_category.slug &&
             @product.custom_category.slug != "" do
            ~p"/stores/#{@store.slug}/#{@product.custom_category.slug}/#{@product.slug}"
          else
            ~p"/stores/#{@store.slug}/products/#{@product.slug}"
          end
        else
          ~p"/stores/#{@store.slug}/products/#{@product.id}"
        end
      }
      class="group block bg-white rounded-3xl shadow-xl hover:shadow-2xl transition-all duration-300 overflow-hidden"
    >
      <!-- Product Image Container - FULL TILE -->
      <div class="relative aspect-square overflow-hidden bg-gray-100">
        <%= if get_product_image(@product) do %>
          <img
            src={get_product_image(@product)}
            alt={@product.title}
            class="w-full h-full object-cover"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center text-gray-400 bg-gray-50">
            <svg class="h-20 w-20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
          </div>
        <% end %>

        <!-- Price Badge -->
        <div class="absolute top-4 right-4">
          <span class="inline-flex items-center px-4 py-3 rounded-full text-lg font-bold bg-white/95 backdrop-blur-sm text-green-600 shadow-xl border border-green-100">
            $<%= @product.price %>
          </span>
        </div>

        <!-- Category Badge -->
        <div class="absolute top-4 left-4">
          <%= if Map.has_key?(@product, :custom_category) && @product.custom_category && Map.has_key?(@product.custom_category, :name) do %>
            <span class="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-blue-500/95 backdrop-blur-sm text-white shadow-xl border border-blue-400">
              <%= @product.custom_category.name %>
            </span>
          <% end %>
        </div>

        <!-- Simple Hover Overlay -->
        <div class="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-all duration-300 flex items-end justify-center">
          <div class="opacity-0 group-hover:opacity-100 transition-all duration-300 pb-6 text-center">
            <h3 class="text-xl font-bold text-white mb-2">
              <%= @product.title %>
            </h3>
            <p class="text-white/90 text-sm">
              Click to view details
            </p>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  # Helper function to get the best available image for a product
  defp get_product_image(product) do
    cond do
      # Try thumbnail first
      product.image_thumb && product.image_thumb != "" -> product.image_thumb
      # Fall back to original image
      product.image_original && product.image_original != "" -> product.image_original
      # Try medium image
      product.image_medium && product.image_medium != "" -> product.image_medium
      # Try large image
      product.image_large && product.image_large != "" -> product.image_large
      # Try additional images if available
      product.additional_images && length(product.additional_images) > 0 ->
        List.first(product.additional_images)
      # No image available
      true -> nil
    end
  end

  # Helper function to get product URL
  defp get_product_url(product) do
    if product.store do
      if product.slug do
        # Check if custom_category is loaded and has a slug
        custom_category_slug = case product do
          %{custom_category: %Ecto.Association.NotLoaded{}} -> nil
          %{custom_category: nil} -> nil
          %{custom_category: custom_category} when is_map(custom_category) ->
            Map.get(custom_category, :slug)
          _ -> nil
        end

        if custom_category_slug do
          "/stores/#{product.store.slug}/#{custom_category_slug}/#{product.slug}"
        else
          "/stores/#{product.store.slug}/products/#{product.slug}"
        end
      else
        "/stores/#{product.store.slug}/products/#{product.id}"
      end
    else
      "#"
    end
  end

  # Helper function to get all available images for a product
  defp get_all_product_images(product) do
    images = []

    # Add images in order of preference
    if product.image_thumb && product.image_thumb != "" do
      images = images ++ [product.image_thumb]
    end

    if product.image_original && product.image_original != "" do
      images = images ++ [product.image_original]
    end

    if product.image_medium && product.image_medium != "" do
      images = images ++ [product.image_medium]
    end

    if product.image_large && product.image_large != "" do
      images = images ++ [product.image_large]
    end

    if product.additional_images && length(product.additional_images) > 0 do
      images = images ++ product.additional_images
    end

    # Remove duplicates and return
    Enum.uniq(images)
  end
end
