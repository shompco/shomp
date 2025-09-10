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
      |> assign(:page_title, "Universal Orders")

    {:ok, socket}
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
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Customer Email</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Shomp Donation</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Merchant Stripe ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Merchant Email</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for order <- @orders do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= order.universal_order_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= order.customer_email %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= order.total_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= order.platform_fee_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= if order.stripe_account_id do %>
                      <div class="text-xs font-mono bg-white text-black border border-gray-300 px-2 py-1 rounded">
                        <%= String.slice(order.stripe_account_id, 0, 20) %>...
                      </div>
                    <% else %>
                      <span class="text-gray-400 text-xs">No Stripe ID</span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= order.merchant_email || "N/A" %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                      case order.status do
                        "completed" -> "bg-green-100 text-green-800"
                        "processing" -> "bg-yellow-100 text-yellow-800"
                        "cancelled" -> "bg-red-100 text-red-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      <%= String.capitalize(order.status) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= Calendar.strftime(order.inserted_at, "%Y-%m-%d %H:%M") %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

      </div>
    </div>
    """
  end


  defp parse_filter_params(params) do
    params
    |> Enum.reject(fn {_k, v} -> v == "" end)
    |> Enum.into(%{})
  end
end
