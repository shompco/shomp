defmodule ShompWeb.StoreLive.MyStores do
  use ShompWeb, :live_view

  alias Shomp.Stores
  alias Shomp.Accounts
  alias Shomp.Products

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # If user doesn't have a tier, redirect to tier selection
    if is_nil(user.tier_id) do
      {:ok, push_navigate(socket, to: ~p"/users/tier-selection")}
    else
      stores = Stores.list_stores_by_user(user.id)
      # Load products for each store
      stores_with_products = Enum.map(stores, fn store ->
        products = Products.list_products_by_store(store.store_id)
        Map.put(store, :products, products)
      end)
      limits = Accounts.check_user_limits(user)

      {:ok,
       assign(socket,
         stores: stores_with_products,
         limits: limits,
         page_title: "My Stores"
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold text-base-content">My Stores</h1>
            <p class="text-base-content/70 mt-2">
              Manage your digital marketplace stores
              (<%= @limits.store_count %>/<%= @limits.store_limit %> stores used)
            </p>
          </div>
          <div class="flex space-x-3">
            <%= if @limits.can_create_store do %>
              <.link
                navigate={~p"/stores/new"}
                class="btn btn-primary"
              >
                Create New Store
              </.link>
            <% else %>
              <div class="tooltip" data-tip="You've reached your tier's store limit. Upgrade to create more stores.">
                <button class="btn btn-primary btn-disabled" disabled>
                  Create New Store
                </button>
              </div>
              <.link
                navigate={~p"/users/tier-upgrade"}
                class="btn btn-outline"
              >
                Upgrade Plan
              </.link>
            <% end %>
          </div>
        </div>

        <%= if Enum.empty?(@stores) do %>
          <div class="text-center py-16">
            <div class="mx-auto h-24 w-24 text-base-content/30 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-base-content mb-2">No stores yet</h3>
            <p class="text-base-content/70 mb-6">Get started by creating your first store to sell digital products.</p>
            <%= if @limits.can_create_store do %>
              <.link
                navigate={~p"/stores/new"}
                class="btn btn-primary"
              >
                Create Your First Store
              </.link>
            <% else %>
              <div class="space-y-4">
                <p class="text-warning font-medium">You've reached your tier's store limit</p>
                <.link
                  navigate={~p"/users/tier-upgrade"}
                  class="btn btn-primary"
                >
                  Upgrade Plan to Create Stores
                </.link>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="space-y-8">
            <%= for store <- @stores do %>
              <div class="card bg-base-100 shadow-md border border-base-300">
                <!-- Store Header -->
                <div class="card-body border-b border-base-300">
                  <div class="flex items-start justify-between mb-4">
                    <div>
                      <h3 class="text-2xl font-semibold text-base-content mb-2">
                        <%= store.name %>
                      </h3>
                      <p class="text-base-content/70 mb-2">
                        <%= if store.description && String.length(store.description) > 0 do %>
                          <%= store.description %>
                        <% else %>
                          No description provided yet.
                        <% end %>
                      </p>
                      <div class="flex items-center space-x-4 text-sm text-base-content/60">
                        <span>Created <%= Calendar.strftime(store.inserted_at, "%B %d, %Y") %></span>
                        <span class="text-primary font-medium">@<%= store.slug %></span>
                        <span class="badge badge-success">
                          Active
                        </span>
                      </div>
                    </div>
                  </div>

                  <!-- Action Buttons -->
                  <div class="flex space-x-3">
                    <.link
                      navigate={~p"/stores/#{store.slug}"}
                      class="btn btn-outline"
                    >
                      View Store
                    </.link>
                    <.link
                      navigate={~p"/dashboard/store"}
                      class="btn btn-primary"
                    >
                      Manage Store
                    </.link>
                    <.link
                      navigate={~p"/dashboard/products/new?store_id=#{store.store_id}"}
                      class="btn btn-secondary"
                    >
                      Add Product
                    </.link>
                  </div>
                </div>

                <!-- Products Section -->
                <div class="card-body">
                  <div class="flex items-center justify-between mb-4">
                    <h4 class="text-lg font-medium text-base-content">
                      Products (<%= length(store.products) %>)
                    </h4>
                    <%= if length(store.products) > 0 do %>
                      <.link
                        navigate={~p"/stores/#{store.slug}"}
                        class="text-sm text-primary hover:text-primary-focus"
                      >
                        View All Products →
                      </.link>
                    <% end %>
                  </div>

                  <%= if Enum.empty?(store.products) do %>
                    <div class="text-center py-8 bg-base-200 rounded-lg">
                      <div class="text-base-content/40 mb-2">
                        <svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                        </svg>
                      </div>
                      <p class="text-base-content/70 mb-4">No products yet</p>
                      <.link
                        navigate={~p"/dashboard/products/new?store_id=#{store.store_id}"}
                        class="btn btn-primary btn-sm"
                      >
                        Add Your First Product
                      </.link>
                    </div>
                  <% else %>
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                      <%= for product <- Enum.take(store.products, 8) do %>
                        <div class="card bg-base-100 border border-base-300 overflow-hidden hover:shadow-md transition-shadow duration-200">
                          <div class="aspect-square bg-base-200 flex items-center justify-center">
                            <%= if get_product_image(product) do %>
                              <img
                                src={get_product_image(product)}
                                alt={product.title}
                                class="w-full h-full object-cover"
                              />
                            <% else %>
                              <div class="text-base-content/40">
                                <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                </svg>
                              </div>
                            <% end %>
                          </div>
                          <div class="card-body p-3">
                            <h5 class="font-medium text-base-content text-sm mb-1 line-clamp-2">
                              <%= product.title %>
                            </h5>
                            <p class="text-lg font-semibold text-primary mb-2">
                              $<%= product.price %>
                            </p>
                            <div class="flex items-center justify-between text-xs text-base-content/60">
                              <span class="capitalize"><%= product.type %></span>
                              <span class="text-primary">Active</span>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <div class="mt-8 text-center">
            <%= if @limits.can_create_store do %>
              <.link
                navigate={~p"/stores/new"}
                class="btn btn-outline"
              >
                Create Another Store
              </.link>
            <% else %>
              <div class="space-y-4">
                <p class="text-gray-500">
                  You've reached your tier's store limit (<%= @limits.store_count %>/<%= @limits.store_limit %> stores).
                </p>
                <.link
                  navigate={~p"/users/tier-upgrade"}
                  class="btn btn-primary"
                >
                  Upgrade Plan for More Stores
                </.link>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
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
end
