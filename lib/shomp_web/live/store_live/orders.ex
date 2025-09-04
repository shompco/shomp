defmodule ShompWeb.StoreLive.Orders do
  use ShompWeb, :live_view

  alias Shomp.Orders
  alias Shomp.Stores

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def handle_info(%{event: "order_updated", payload: updated_order}, socket) do
    # Update the order in the list if it exists, making sure to get proper preloads
    updated_orders = Enum.map(socket.assigns.orders, fn order ->
      if order.id == updated_order.id do
        # Get the full order with all preloads for proper display
        Orders.get_order!(updated_order.id)
      else
        order
      end
    end)
    
    {:noreply, assign(socket, :orders, updated_orders)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl">
        <div class="mb-8">
          <.header>
            Order Management
            <:subtitle>
              <%= if @store do %>
                Manage orders for your store: <%= @store.name %>
              <% else %>
                Select a store to manage orders
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <!-- Store Selection (shown when user has multiple stores and none selected) -->
        <%= if @store == nil and length(@stores) > 1 do %>
          <div class="bg-base-100 shadow rounded-lg p-6 mb-8">
            <h2 class="text-lg font-medium text-base-content mb-4">Select a Store</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for store <- @stores do %>
                <div class="border border-base-300 rounded-lg p-4 hover:bg-base-200 transition-colors cursor-pointer"
                     phx-click="select_store" 
                     phx-value-store_id={store.id}>
                  <h3 class="font-medium text-base-content"><%= store.name %></h3>
                  <p class="text-sm text-base-content/70"><%= store.description %></p>
                  <p class="text-xs text-base-content/50 mt-2">Store ID: <%= store.store_id %></p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Store Switcher (shown when user has multiple stores and one is selected) -->
        <%= if @store != nil and length(@stores) > 1 do %>
          <div class="bg-base-100 shadow rounded-lg p-4 mb-8">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-sm font-medium text-base-content">Current Store</h3>
                <p class="text-lg font-semibold text-base-content"><%= @store.name %></p>
              </div>
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-outline btn-sm">
                  Switch Store
                  <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
                  <%= for store <- @stores do %>
                    <li>
                      <a href={~p"/dashboard/orders?store_id=#{store.id}"} 
                         class={if store.id == @store.id, do: "active", else: ""}>
                        <%= store.name %>
                        <%= if store.id == @store.id do %>
                          <span class="badge badge-primary badge-sm">Current</span>
                        <% end %>
                      </a>
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Order Stats (only shown when store is selected) -->
        <%= if @store do %>
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
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
                <svg class="w-8 h-8 text-warning" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-base-content/70">Pending</p>
                <p class="text-2xl font-semibold text-base-content"><%= count_orders_by_status(@orders, "pending") %></p>
              </div>
            </div>
          </div>

          <div class="bg-base-100 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="w-8 h-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-base-content/70">Completed</p>
                <p class="text-2xl font-semibold text-base-content"><%= count_orders_by_status(@orders, "completed") %></p>
              </div>
            </div>
          </div>

          <div class="bg-base-100 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="w-8 h-8 text-error" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-base-content/70">Cancelled</p>
                <p class="text-2xl font-semibold text-base-content"><%= count_orders_by_status(@orders, "cancelled") %></p>
              </div>
            </div>
          </div>
        </div>

        <!-- Orders List -->
        <div class="bg-base-100 shadow rounded-lg">
          <%= if Enum.empty?(@orders) do %>
            <div class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-base-content">No orders yet</h3>
              <p class="mt-1 text-sm text-base-content/70">Orders for your products will appear here.</p>
            </div>
          <% else %>
            <div class="px-6 py-4 border-b border-base-300">
              <h2 class="text-lg font-medium text-base-content">Recent Orders</h2>
            </div>
            
            <ul class="divide-y divide-base-300">
              <%= for order <- @orders do %>
                <li class="px-6 py-6">
                  <div class="flex items-center justify-between mb-4">
                    <div>
                      <h3 class="text-lg font-medium text-base-content">
                        Order <%= order.immutable_id %>
                      </h3>
                      <p class="text-sm text-base-content/70">
                        <%= Calendar.strftime(order.inserted_at, "%B %d, %Y at %I:%M %p") %>
                      </p>
                      <p class="text-sm text-base-content/70">
                        Customer: <%= order.user.username || order.user.email %>
                      </p>
                    </div>
                    <div class="text-right">
                      <p class="text-lg font-bold text-base-content">
                        $<%= Decimal.to_string(order.total_amount) %>
                      </p>
                      <div class="flex flex-col gap-1 items-end">
                        <!-- Main order status -->
                        <span class={get_status_badge_class(order.status)}>
                          <%= String.capitalize(order.status) %>
                        </span>
                        
                        <!-- Additional status badges (only show if meaningful) -->
                        <%= if should_show_fulfillment_status?(order) do %>
                          <span class="badge badge-info badge-sm">
                            Fulfillment: <%= String.capitalize(order.fulfillment_status) %>
                          </span>
                        <% end %>
                        
                        <%= if should_show_payment_status?(order) do %>
                          <span class="badge badge-warning badge-sm">
                            Payment: <%= String.capitalize(order.payment_status) %>
                          </span>
                        <% end %>
                        
                        <!-- Shipping Status -->
                        <%= if should_show_shipping_status?(order) do %>
                          <span class={get_shipping_badge_class(order.shipping_status)}>
                            <%= format_shipping_status(order.shipping_status) %>
                          </span>
                        <% end %>
                        
                        <!-- Tracking Information -->
                        <%= if order.tracking_number do %>
                          <span class="badge badge-outline badge-sm">
                            📦 <%= order.carrier || "Tracking" %>: <%= order.tracking_number %>
                          </span>
                        <% end %>
                        
                        <!-- Delivery Information -->
                        <%= if order.delivered_at do %>
                          <span class="badge badge-success badge-sm">
                            ✅ Delivered <%= Calendar.strftime(order.delivered_at, "%m/%d") %>
                          </span>
                        <% else %>
                          <%= if order.estimated_delivery do %>
                            <span class="badge badge-info badge-sm">
                              📅 Est. Delivery: <%= Calendar.strftime(order.estimated_delivery, "%m/%d") %>
                            </span>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                  </div>
                  
                  <!-- Order Items -->
                  <div class="space-y-3 mb-4">
                    <%= for order_item <- order.order_items do %>
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
                              Quantity: <%= order_item.quantity %> • $<%= Decimal.to_string(order_item.price) %>
                            </p>
                          </div>
                        </div>
                        <div class="flex items-center space-x-2">
                          <a href={~p"/#{@store.slug}/products/#{order_item.product_id}"} class="btn btn-xs btn-outline">
                            View Product
                          </a>
                        </div>
                      </div>
                    <% end %>
                  </div>
                  
                  <!-- Order Actions -->
                  <div class="flex items-center justify-between pt-4 border-t border-base-300">
                    <div class="text-sm text-base-content/70">
                      <%= length(order.order_items) %> item<%= if length(order.order_items) != 1, do: "s", else: "" %>
                    </div>
                    <div class="flex items-center space-x-2">
                      <%= if order.status == "pending" do %>
                        <button 
                          phx-click="update_status"
                          phx-value-order_id={order.id}
                          phx-value-status="processing"
                          class="btn btn-sm btn-primary"
                        >
                          Mark as Processing
                        </button>
                      <% end %>
                      <%= if order.status == "processing" do %>
                        <button 
                          phx-click="update_status"
                          phx-value-order_id={order.id}
                          phx-value-status="completed"
                          class="btn btn-sm btn-success"
                        >
                          Mark as Completed
                        </button>
                      <% end %>
                    </div>
                  </div>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    stores = Stores.get_stores_by_user(user.id)
    
    case stores do
      [] ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have a store yet. Create one first!")
         |> push_navigate(to: ~p"/stores/new")}
      
      [single_store] ->
        # User has only one store, use it directly
        orders = Orders.list_store_orders(single_store.store_id)
        
        # Subscribe to order updates for this store
        Phoenix.PubSub.subscribe(Shomp.PubSub, "store_orders:#{single_store.store_id}")
        
        {:ok, assign(socket, 
          store: single_store,
          stores: stores,
          orders: orders,
          page_title: "Order Management"
        )}
      
      multiple_stores ->
        # User has multiple stores, check if store_id is specified in params
        case params["store_id"] do
          nil ->
            # No store selected, show store selection
            {:ok, assign(socket, 
              store: nil,
              stores: multiple_stores,
              orders: [],
              page_title: "Order Management - Select Store"
            )}
          
          store_id ->
            # Find the selected store
            case Enum.find(multiple_stores, &(&1.id == String.to_integer(store_id))) do
              nil ->
                # Invalid store_id, show store selection
                {:ok, assign(socket, 
                  store: nil,
                  stores: multiple_stores,
                  orders: [],
                  page_title: "Order Management - Select Store"
                )}
              
              selected_store ->
                # Valid store selected, show its orders
                orders = Orders.list_store_orders(selected_store.store_id)
                
                # Subscribe to order updates for this store
                Phoenix.PubSub.subscribe(Shomp.PubSub, "store_orders:#{selected_store.store_id}")
                
                {:ok, assign(socket, 
                  store: selected_store,
                  stores: multiple_stores,
                  orders: orders,
                  page_title: "Order Management"
                )}
            end
        end
    end
  end

  @impl true
  def handle_event("select_store", %{"store_id" => store_id}, socket) do
    # Redirect to the same page with store_id parameter
    {:noreply, push_navigate(socket, to: ~p"/dashboard/orders?store_id=#{store_id}")}
  end

  @impl true
  def handle_event("update_status", %{"order_id" => order_id, "status" => status}, socket) do
    order = Orders.get_order!(order_id)
    
    case Orders.update_order_status(order, status) do
      {:ok, updated_order} ->
        # Don't manually update the list here - the PubSub broadcast will handle it
        {:noreply, put_flash(socket, :info, "Order status updated to #{status}")}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update order status")}
    end
  end

  defp count_orders_by_status(orders, status) do
    Enum.count(orders, fn order -> order.status == status end)
  end

  defp get_status_badge_class(status) do
    case status do
      "completed" -> "badge badge-success"
      "processing" -> "badge badge-info"
      "pending" -> "badge badge-warning"
      "cancelled" -> "badge badge-error"
      _ -> "badge badge-neutral"
    end
  end

  defp should_show_fulfillment_status?(order) do
    # Only show fulfillment status if it's meaningful (not the default "unfulfilled" for pending orders)
    case {order.status, order.fulfillment_status} do
      {"pending", "unfulfilled"} -> false
      {"cancelled", _} -> false
      {_, "unfulfilled"} -> false
      {_, nil} -> false
      _ -> true
    end
  end

  defp should_show_payment_status?(order) do
    # Only show payment status if it's meaningful and not obvious from order status
    case {order.status, order.payment_status} do
      {"pending", "pending"} -> false
      {"completed", "paid"} -> false  # Don't show "paid" for completed orders (obvious)
      {"cancelled", _} -> false
      {_, nil} -> false
      _ -> true
    end
  end

  defp should_show_shipping_status?(order) do
    # Only show shipping status for physical goods that have meaningful status
    case order.shipping_status do
      "not_shipped" -> false
      nil -> false
      _ -> true
    end
  end

  defp get_shipping_badge_class(shipping_status) do
    case shipping_status do
      "preparing" -> "badge badge-warning badge-sm"
      "shipped" -> "badge badge-info badge-sm"
      "in_transit" -> "badge badge-primary badge-sm"
      "out_for_delivery" -> "badge badge-accent badge-sm"
      "delivered" -> "badge badge-success badge-sm"
      "delivery_failed" -> "badge badge-error badge-sm"
      "returned" -> "badge badge-neutral badge-sm"
      _ -> "badge badge-neutral badge-sm"
    end
  end

  defp format_shipping_status(shipping_status) do
    case shipping_status do
      "preparing" -> "📦 Preparing"
      "shipped" -> "🚚 Shipped"
      "in_transit" -> "🚛 In Transit"
      "out_for_delivery" -> "🚗 Out for Delivery"
      "delivered" -> "✅ Delivered"
      "delivery_failed" -> "❌ Delivery Failed"
      "returned" -> "↩️ Returned"
      _ -> String.capitalize(shipping_status || "Unknown")
    end
  end
end
