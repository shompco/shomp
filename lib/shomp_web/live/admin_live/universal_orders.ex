defmodule ShompWeb.AdminLive.UniversalOrders do
  use ShompWeb, :live_view

  alias Shomp.UniversalOrders
  alias Shomp.PaymentSplits
  alias Shomp.Refunds

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(_params, _session, socket) do
    orders = UniversalOrders.list_universal_orders()
    
    socket = 
      socket
      |> assign(:orders, orders)
      |> assign(:selected_order, nil)
      |> assign(:payment_splits, [])
      |> assign(:refunds, [])
      |> assign(:page_title, "Universal Orders")

    {:ok, socket}
  end

  def handle_event("view_order", %{"universal_order_id" => order_id}, socket) do
    order = UniversalOrders.get_universal_order_by_id(order_id)
    splits = PaymentSplits.get_splits_by_universal_order(order_id)
    refunds = Refunds.get_refunds_by_universal_order(order_id)
    
    {:noreply,
     socket
     |> assign(:selected_order, order)
     |> assign(:payment_splits, splits)
     |> assign(:refunds, refunds)}
  end

  def handle_event("filter_orders", %{"filter" => filter_params}, socket) do
    filters = parse_filter_params(filter_params)
    orders = UniversalOrders.list_universal_orders(filters)
    
    {:noreply, assign(socket, :orders, orders)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Universal Orders</h1>
          <p class="mt-2 text-gray-600">Track multi-store orders and payment splits</p>
        </div>

        <!-- Filters -->
        <div class="bg-white shadow rounded-lg p-6 mb-6">
          <form phx-submit="filter_orders" class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Status</label>
              <select name="filter[status]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                <option value="">All Statuses</option>
                <option value="pending">Pending</option>
                <option value="processing">Processing</option>
                <option value="completed">Completed</option>
                <option value="cancelled">Cancelled</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Payment Status</label>
              <select name="filter[payment_status]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                <option value="">All Payment Statuses</option>
                <option value="pending">Pending</option>
                <option value="paid">Paid</option>
                <option value="failed">Failed</option>
                <option value="refunded">Refunded</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Date From</label>
              <input type="date" name="filter[date_from]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
            </div>
            <div class="flex items-end">
              <button type="submit" class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700">
                Filter
              </button>
            </div>
          </form>
        </div>

        <!-- Orders Table -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Order ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Customer</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Platform Fee</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for order <- @orders do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= order.universal_order_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    User #<%= order.user_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= order.total_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= order.platform_fee_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                      <%= order.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= Calendar.strftime(order.inserted_at, "%Y-%m-%d %H:%M") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button
                      phx-click="view_order"
                      phx-value-universal_order_id={order.universal_order_id}
                      class="text-indigo-600 hover:text-indigo-900"
                    >
                      View Details
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Order Details Modal -->
        <%= if @selected_order do %>
          <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" phx-click="close_modal">
            <div class="relative top-20 mx-auto p-5 border w-11/12 md:w-3/4 lg:w-1/2 shadow-lg rounded-md bg-white" phx-click-away="close_modal">
              <div class="mt-3">
                <div class="flex justify-between items-center mb-4">
                  <h3 class="text-lg font-medium text-gray-900">Order Details: <%= @selected_order.universal_order_id %></h3>
                  <button phx-click="close_modal" class="text-gray-400 hover:text-gray-600">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                  </button>
                </div>
                
                <!-- Order Items -->
                <div class="mb-6">
                  <h4 class="text-md font-medium text-gray-900 mb-2">Order Items</h4>
                  <div class="space-y-2">
                    <%= for item <- @selected_order.universal_order_items do %>
                      <div class="flex justify-between items-center p-2 bg-gray-50 rounded">
                        <span class="text-sm"><%= item.product.title %> x <%= item.quantity %></span>
                        <span class="text-sm font-medium">$<%= item.total_price %></span>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Payment Splits -->
                <div class="mb-6">
                  <h4 class="text-md font-medium text-gray-900 mb-2">Payment Splits</h4>
                  <div class="space-y-2">
                    <%= for split <- @payment_splits do %>
                      <div class="flex justify-between items-center p-2 bg-blue-50 rounded">
                        <span class="text-sm">Store: <%= split.store_id %></span>
                        <span class="text-sm font-medium">$<%= split.total_amount %></span>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Refunds -->
                <%= if length(@refunds) > 0 do %>
                  <div class="mb-6">
                    <h4 class="text-md font-medium text-gray-900 mb-2">Refunds</h4>
                    <div class="space-y-2">
                      <%= for refund <- @refunds do %>
                        <div class="flex justify-between items-center p-2 bg-red-50 rounded">
                          <span class="text-sm">Store: <%= refund.store_id %> - <%= refund.refund_reason %></span>
                          <span class="text-sm font-medium">$<%= refund.refund_amount %></span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :selected_order, nil)}
  end

  defp parse_filter_params(params) do
    params
    |> Enum.reject(fn {_k, v} -> v == "" end)
    |> Enum.into(%{})
  end
end
