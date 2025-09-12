defmodule ShompWeb.DownloadLive.Purchases do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Downloads

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Get all user universal orders with payment splits and order items loaded
    universal_orders = Shomp.UniversalOrders.list_user_universal_orders(user_id)
    |> Shomp.Repo.preload([:payment_splits, universal_order_items: :product])

    # Manually fetch store data and categories for each product
    orders_with_stores = Enum.map(universal_orders, fn universal_order ->
      order_items_with_stores = Enum.map(universal_order.universal_order_items, fn order_item ->
        store = Shomp.Stores.get_store_by_store_id(order_item.product.store_id)

        # Load platform category if it exists
        product_with_store = %{order_item.product | store: store}
        product_with_categories = if product_with_store.category_id do
          case Shomp.Repo.get(Shomp.Categories.Category, product_with_store.category_id) do
            nil -> product_with_store
            category -> %{product_with_store | category: category}
          end
        else
          product_with_store
        end

        # Load custom category if it exists
        product_with_all = if product_with_categories.custom_category_id do
          case Shomp.Repo.get(Shomp.Categories.Category, product_with_categories.custom_category_id) do
            nil -> product_with_categories
            custom_category -> %{product_with_categories | custom_category: custom_category}
          end
        else
          product_with_categories
        end

        %{order_item | product: product_with_all}
      end)
      %{universal_order | universal_order_items: order_items_with_stores}
    end)

    # Get download stats for digital products
    stats = Downloads.get_user_download_stats(user_id)

    {:ok, assign(socket,
      orders: orders_with_stores,
      stats: stats,
      get_download_token: &get_download_token/2
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-12">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">My Purchases</h1>
          <p class="text-lg text-base-content/70 mt-2">All your purchased products and download history</p>
        </div>

        <!-- Stats -->
        <%= if @stats do %>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div class="bg-base-100 rounded-lg shadow p-6">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="w-8 h-8 text-info" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
                  </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-base-content/70">Total Orders</p>
                  <p class="text-2xl font-semibold text-base-content"><%= length(@orders) %></p>
                </div>
              </div>
            </div>

            <div class="bg-base-100 rounded-lg shadow p-6">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="w-8 h-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-base-content/70">Total Items</p>
                  <p class="text-2xl font-semibold text-base-content"><%= Enum.reduce(@orders, 0, fn order, acc -> acc + length(order.universal_order_items) end) %></p>
                </div>
              </div>
            </div>

            <div class="bg-base-100 rounded-lg shadow p-6">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="w-8 h-8 text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                  </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-base-content/70">Unique Products</p>
                  <p class="text-2xl font-semibold text-base-content"><%= @stats.unique_products || 0 %></p>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Purchases List -->
        <div class="bg-base-100 shadow rounded-lg">
          <%= if Enum.empty?(@orders) do %>
            <div class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-base-content">No purchases yet</h3>
              <p class="mt-1 text-sm text-base-content/70">Start shopping to see your purchases here.</p>
              <div class="mt-6">
                <a href="/" class="btn btn-primary">
                  Browse Products
                </a>
              </div>
            </div>
          <% else %>
            <div class="px-6 py-4 border-b border-base-300">
              <h2 class="text-lg font-medium text-base-content">Recent Purchases</h2>
            </div>

            <ul class="divide-y divide-base-300">
              <%= for order <- @orders do %>
                <li class="px-6 py-6">
                  <div class="flex items-center justify-between mb-4">
                    <div>
                      <h3 class="text-lg font-medium text-base-content">
                        Order <%= order.universal_order_id %>
                      </h3>
                      <p class="text-sm text-base-content/70">
                        <%= Calendar.strftime(order.inserted_at, "%B %d, %Y at %I:%M %p") %>
                      </p>
                    </div>
                    <div class="text-right">
                      <p class="text-lg font-bold text-base-content">
                        $<%= Decimal.to_string(order.total_amount) %>
                      </p>
                      <div class="flex flex-col gap-1 items-end">
                        <%= if order.payment_status == "paid" do %>
                          <span class="badge badge-success">
                            Complete
                          </span>
                        <% else %>
                          <span class="badge badge-warning">
                            <%= String.capitalize(order.payment_status || "pending") %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <!-- Order Items -->
                  <div class="space-y-3 mb-4">
                    <%= for order_item <- order.universal_order_items do %>
                      <div class="flex items-center justify-between py-3 px-4 bg-base-200 rounded-md">
                        <div class="flex items-center space-x-3">
                          <div class="w-10 h-10 bg-base-300 rounded flex items-center justify-center">
                            <svg class="w-5 h-5 text-base-content/60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                            </svg>
                          </div>
                          <div>
                            <p class="text-sm font-medium text-base-content">
                              <%= order_item.product.title %>
                            </p>
                            <p class="text-xs text-base-content/70">
                              <%= order_item.product.store.name %> • $<%= Decimal.to_string(order_item.price) %>
                            </p>
                          </div>
                        </div>
                        <div class="flex items-center space-x-2">
                          <a href={
                            if order_item.product.slug do
                              if order_item.product.custom_category do
                                ~p"/stores/#{order_item.product.store.slug}/#{order_item.product.custom_category.slug}/#{order_item.product.slug}"
                              else
                                ~p"/stores/#{order_item.product.store.slug}/#{order_item.product.slug}"
                              end
                            else
                              ~p"/stores/#{order_item.product.store.slug}/products/#{order_item.product_id}"
                            end
                          } class="btn btn-xs btn-outline">
                            View Product
                          </a>
                          <%= if order_item.product.type == "digital" do %>
                            <%= if @get_download_token.(order_item.product_id, order.user_id) do %>
                              <a href={~p"/downloads/#{@get_download_token.(order_item.product_id, order.user_id)}"} class="btn btn-xs btn-primary">
                                Download
                              </a>
                            <% end %>
                          <% end %>
                          <a href={~p"/stores/#{order_item.product.store.slug}/products/#{order_item.product_id}/reviews/new"} class="btn btn-xs btn-secondary">
                            Review
                          </a>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <!-- Order Actions -->
                  <div class="flex items-center justify-between pt-4 border-t border-base-300">
                    <div class="text-sm text-base-content/70">
                      <%= length(order.universal_order_items) %> item<%= if length(order.universal_order_items) != 1, do: "s", else: "" %>
                    </div>
                    <a href={~p"/dashboard/purchases/#{order.universal_order_id}"} class="btn btn-primary btn-sm">
                      View Purchase Details
                    </a>
                  </div>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to get download token for a product and user
  defp get_download_token(product_id, user_id) do
    case Downloads.get_download_by_product_and_user(product_id, user_id) do
      nil -> nil
      download -> download.token
    end
  end
end
