defmodule ShompWeb.AdminLive.PaymentSplits do
  use ShompWeb, :live_view

  alias Shomp.PaymentSplits
  alias Shomp.Stores

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(%{"universal_order_id" => order_id}, _session, socket) do
    splits = PaymentSplits.get_splits_by_universal_order(order_id)
    splits_with_stores = Enum.map(splits, fn split ->
      store = Stores.get_store_by_store_id(split.store_id)
      Map.put(split, :store, store)
    end)
    
    socket = 
      socket
      |> assign(:splits, splits_with_stores)
      |> assign(:universal_order_id, order_id)
      |> assign(:page_title, "Payment Splits - #{order_id}")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Payment Splits</h1>
              <p class="mt-2 text-gray-600">Order: <%= @universal_order_id %></p>
            </div>
            <div>
              <.link
                navigate={~p"/admin/universal-orders"}
                class="bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700"
              >
                ← Back to Orders
              </.link>
            </div>
          </div>
        </div>

        <!-- Splits Table -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Split ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Store</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Store Amount</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Platform Fee</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Refunded</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for split <- @splits do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= split.payment_split_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= if split.store do %>
                      <%= split.store.name %>
                    <% else %>
                      Unknown Store
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.store_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.platform_fee_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.total_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.refunded_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">
                      <%= split.transfer_status %>
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Summary -->
        <div class="mt-6 grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Store Revenue</dt>
                    <dd class="text-lg font-medium text-gray-900">
                      $<%= @splits |> Enum.reduce(Decimal.new(0), fn split, acc -> Decimal.add(acc, split.store_amount) end) %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"></path>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Platform Fees</dt>
                    <dd class="text-lg font-medium text-gray-900">
                      $<%= @splits |> Enum.reduce(Decimal.new(0), fn split, acc -> Decimal.add(acc, split.platform_fee_amount) end) %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Refunded</dt>
                    <dd class="text-lg font-medium text-gray-900">
                      $<%= @splits |> Enum.reduce(Decimal.new(0), fn split, acc -> Decimal.add(acc, split.refunded_amount) end) %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
