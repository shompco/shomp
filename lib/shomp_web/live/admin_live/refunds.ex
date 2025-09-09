defmodule ShompWeb.AdminLive.Refunds do
  use ShompWeb, :live_view

  alias Shomp.Refunds
  alias Shomp.Stores

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(_params, _session, socket) do
    refunds = Refunds.list_all_refunds()
    refunds_with_stores = Enum.map(refunds, fn refund ->
      store = Stores.get_store_by_store_id(refund.store_id)
      Map.put(refund, :store, store)
    end)
    
    socket = 
      socket
      |> assign(:refunds, refunds_with_stores)
      |> assign(:page_title, "Refund Management")

    {:ok, socket}
  end

  def handle_event("process_refund", %{"refund_id" => refund_id}, socket) do
    admin_user_id = socket.assigns.current_scope.user.id
    
    case Refunds.process_refund(refund_id, admin_user_id) do
      {:ok, _refund} ->
        refunds = Refunds.list_all_refunds()
        refunds_with_stores = Enum.map(refunds, fn refund ->
          store = Stores.get_store_by_store_id(refund.store_id)
          Map.put(refund, :store, store)
        end)
        
        {:noreply, 
         socket
         |> put_flash(:info, "Refund processed successfully")
         |> assign(:refunds, refunds_with_stores)}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to process refund")}
    end
  end

  def handle_event("filter_refunds", %{"filter" => filter_params}, socket) do
    filters = parse_filter_params(filter_params)
    refunds = Refunds.list_all_refunds(filters)
    refunds_with_stores = Enum.map(refunds, fn refund ->
      store = Stores.get_store_by_store_id(refund.store_id)
      Map.put(refund, :store, store)
    end)
    
    {:noreply, assign(socket, :refunds, refunds_with_stores)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Refund Management</h1>
          <p class="mt-2 text-gray-600">Track and process refunds with store attribution</p>
        </div>

        <!-- Filters -->
        <div class="bg-white shadow rounded-lg p-6 mb-6">
          <form phx-submit="filter_refunds" class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Status</label>
              <select name="filter[status]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                <option value="">All Statuses</option>
                <option value="pending">Pending</option>
                <option value="succeeded">Succeeded</option>
                <option value="failed">Failed</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Refund Type</label>
              <select name="filter[refund_type]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                <option value="">All Types</option>
                <option value="full">Full</option>
                <option value="partial">Partial</option>
                <option value="item_specific">Item Specific</option>
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

        <!-- Refunds Table -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Refund ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Order ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Store (Debited)</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Amount</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reason</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for refund <- @refunds do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= refund.refund_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= refund.universal_order_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= if refund.store do %>
                      <%= refund.store.name %>
                    <% else %>
                      Unknown Store
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= refund.refund_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= refund.refund_reason %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= refund.refund_type %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                      case refund.status do
                        "pending" -> "bg-yellow-100 text-yellow-800"
                        "succeeded" -> "bg-green-100 text-green-800"
                        "failed" -> "bg-red-100 text-red-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      <%= refund.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= Calendar.strftime(refund.inserted_at, "%Y-%m-%d %H:%M") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <%= if refund.status == "pending" do %>
                      <button
                        phx-click="process_refund"
                        phx-value-refund_id={refund.refund_id}
                        class="text-green-600 hover:text-green-900"
                      >
                        Process
                      </button>
                    <% else %>
                      <span class="text-gray-400">Processed</span>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Summary Stats -->
        <div class="mt-6 grid grid-cols-1 md:grid-cols-4 gap-6">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Pending Refunds</dt>
                    <dd class="text-lg font-medium text-gray-900">
                      <%= @refunds |> Enum.count(&(&1.status == "pending")) %>
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
                  <svg class="h-6 w-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Processed Today</dt>
                    <dd class="text-lg font-medium text-gray-900">
                      <%= @refunds |> Enum.count(&(&1.status == "succeeded" && Date.compare(Date.utc_today(), Date.utc_today()) == :eq)) %>
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
                  <svg class="h-6 w-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Refunded</dt>
                    <dd class="text-lg font-medium text-gray-900">
                      $<%= @refunds |> Enum.filter(&(&1.status == "succeeded")) |> Enum.reduce(Decimal.new(0), fn refund, acc -> Decimal.add(acc, refund.refund_amount) end) %>
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
                  <svg class="h-6 w-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Failed Refunds</dt>
                    <dd class="text-lg font-medium text-gray-900">
                      <%= @refunds |> Enum.count(&(&1.status == "failed")) %>
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

  defp parse_filter_params(params) do
    params
    |> Enum.reject(fn {_k, v} -> v == "" end)
    |> Enum.into(%{})
  end
end
