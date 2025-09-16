defmodule ShompWeb.SellerOrderLive.Index do
  use ShompWeb, :live_view

  alias Shomp.UniversalOrders
  alias Shomp.Stores
  import ShompWeb.OrderComponents

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-7xl">
        <div class="mb-8">
          <.header>
            Your Customer's Order Management
            <:subtitle>Manage orders for all your customers</:subtitle>
          </.header>
        </div>

        <!-- Store Orders -->
        <%= if Enum.empty?(@store_orders) do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-base-content">No stores yet</h3>
            <p class="mt-1 text-sm text-base-content/60">Create a store to start selling and see orders here.</p>
            <div class="mt-6">
              <.link href={~p"/stores/new"} class="btn btn-primary">
                Create Your First Store
              </.link>
            </div>
          </div>
        <% else %>
          <%= for {store, orders} <- @store_orders do %>
            <div class="mb-8">
              <!-- Store Header -->
              <div class="bg-base-100 border border-base-300 rounded-lg mb-4">
                <div class="px-6 py-4 border-b border-base-300">
                  <div class="flex items-center justify-between">
                    <div>
                      <h2 class="text-xl font-semibold text-base-content"><%= store.name %></h2>
                      <p class="text-sm text-base-content/60"><%= store.description %></p>
                    </div>
                    <div class="text-right">
                      <p class="text-sm text-base-content/60">
                        <%= length(orders) %> <%= if length(orders) == 1, do: "order", else: "orders" %>
                      </p>
                    </div>
                  </div>
                </div>

                <!-- Orders List -->
                <div class="divide-y divide-base-300">
                  <%= if Enum.empty?(orders) do %>
                    <div class="px-6 py-8 text-center">
                      <svg class="mx-auto h-8 w-8 text-base-content/40 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                      </svg>
                      <h3 class="text-sm font-medium text-base-content mb-1">No orders yet</h3>
                      <p class="text-xs text-base-content/60">Orders from this store will appear here when customers make purchases.</p>
                    </div>
                  <% else %>
                    <%= for order <- orders do %>
                    <div class="px-6 py-4 hover:bg-base-50 transition-colors">
                      <div class="flex items-center justify-between">
                        <div class="flex-1">
                          <div class="flex items-center space-x-4">
                            <!-- Order Items -->
                            <div class="flex-1">
                              <div class="flex items-center space-x-2 mb-2">
                                <span class="text-sm font-medium text-base-content">
                                  Order #<%= order.universal_order_id %>
                                </span>
                                <.status_badge status={order.shipping_status} class="badge-sm" />
                                <%= if order.tracking_number do %>
                                  <span class="badge badge-sm badge-primary">
                                    Tracked
                                  </span>
                                <% end %>
                              </div>

                              <!-- Order Items -->
                              <div class="space-y-1">
                                <%= for item <- order.universal_order_items do %>
                                  <div class="flex items-center justify-between text-sm">
                                    <div class="flex items-center space-x-2">
                                      <%= if item.product.image_thumb do %>
                                        <img src={item.product.image_thumb} alt={item.product.title} class="w-8 h-8 rounded object-cover" />
                                      <% else %>
                                        <div class="w-8 h-8 bg-base-200 rounded flex items-center justify-center">
                                          <svg class="w-4 h-4 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                          </svg>
                                        </div>
                                      <% end %>
                                      <span class="text-base-content"><%= item.product.title %></span>
                                      <span class="text-base-content/60">×<%= item.quantity %></span>
                                    </div>
                                    <span class="font-medium">$<%= Decimal.to_string(item.unit_price, :normal) %></span>
                                  </div>
                                <% end %>
                              </div>

                              <!-- Customer Info -->
                              <div class="mt-2 text-xs text-base-content/60">
                                <p>Customer: <%= order.user.name || order.user.email %></p>
                                <p>Ordered: <%= Calendar.strftime(order.inserted_at, "%b %d, %Y at %I:%M %p") %></p>
                                <%= if order.tracking_number do %>
                                  <p>Tracking: <%= order.tracking_number %></p>
                                <% end %>
                              </div>
                            </div>

                            <!-- Order Total -->
                            <div class="text-right">
                              <p class="text-lg font-semibold text-base-content">
                                $<%= Decimal.to_string(order.total_amount, :normal) %>
                              </p>
                            </div>
                          </div>
                        </div>

                        <!-- Action Buttons -->
                        <div class="flex items-center space-x-2 ml-4">
                          <.link
                            href={~p"/dashboard/orders/universal/#{order.universal_order_id}"}
                            class="btn btn-sm btn-outline"
                          >
                            Manage
                          </.link>
                        </div>
                      </div>
                    </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get all stores for this user
    stores = Stores.list_stores_by_user(user.id)

    # Get orders for each store, grouped by store (show all stores, even with zero orders)
    store_orders = Enum.map(stores, fn store ->
      orders = UniversalOrders.list_universal_orders_by_store(store.store_id)
      {store, orders}
    end)

    socket =
      socket
      |> assign(:store_orders, store_orders)
      |> assign(:page_title, "Your Customer's Order Management")

    {:ok, socket}
  end

  @impl true
  def handle_info(%{event: "order_updated", payload: updated_order}, socket) do
    # Update the order in the list if it exists
    updated_store_orders = Enum.map(socket.assigns.store_orders, fn {store, orders} ->
      updated_orders = Enum.map(orders, fn order ->
        if order.id == updated_order.id do
          # Get the full order with all preloads for proper display
          UniversalOrders.get_universal_order!(updated_order.id)
        else
          order
        end
      end)
      {store, updated_orders}
    end)

    {:noreply, assign(socket, :store_orders, updated_store_orders)}
  end

  defp get_status_badge_class(status) do
    case status do
      "completed" -> "success"
      "pending" -> "warning"
      "processing" -> "info"
      "cancelled" -> "error"
      _ -> "neutral"
    end
  end

  defp get_payment_status_badge_class(status) do
    case status do
      "paid" -> "success"
      "pending" -> "warning"
      "failed" -> "error"
      "refunded" -> "neutral"
      "partially_refunded" -> "info"
      _ -> "neutral"
    end
  end
end
