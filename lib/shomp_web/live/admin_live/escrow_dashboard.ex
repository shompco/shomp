defmodule ShompWeb.AdminLive.EscrowDashboard do
  use ShompWeb, :live_view

  alias Shomp.PaymentSplits
  alias Shomp.UniversalOrders
  alias Shomp.Stores

  @impl true
  def mount(_params, _session, socket) do
    # Always load data immediately, no loading state needed
    {:ok, updated_socket} = load_escrow_data(socket)
    {:ok, updated_socket}
  end

  @impl true
  def handle_info({:load_escrow_data}, socket) do
    {:ok, updated_socket} = load_escrow_data(socket)
    {:noreply, updated_socket}
  end

  defp load_escrow_data(socket) do
    # Get escrow payment splits
    escrow_splits = PaymentSplits.list_escrow_payment_splits()
    
    # Get direct transfer payment splits (completed KYC)
    direct_splits = PaymentSplits.list_direct_payment_splits()
    
    # Calculate totals
    escrow_total = calculate_escrow_total(escrow_splits)
    direct_total = calculate_direct_total(direct_splits)
    platform_total = calculate_platform_total(escrow_splits ++ direct_splits)
    
    # Calculate pre-KYC donation hold (platform fees from escrow payments)
    pre_kyc_donation_total = calculate_pre_kyc_donation_total(escrow_splits)
    
    escrow_data = %{
      escrow_splits: escrow_splits,
      direct_splits: direct_splits,
      escrow_total: escrow_total,
      direct_total: direct_total,
      platform_total: platform_total,
      pre_kyc_donation_total: pre_kyc_donation_total,
      total_escrow_stores: length(Enum.uniq_by(escrow_splits, & &1.store_id)),
      total_direct_stores: length(Enum.uniq_by(direct_splits, & &1.store_id))
    }
    
    {:ok, assign(socket, escrow_data: escrow_data, loading: false)}
  end

  defp calculate_escrow_total(splits) do
    result = splits
    |> Enum.map(fn split -> 
      case split.store_amount do
        nil -> 0.0
        amount -> Decimal.to_float(amount)
      end
    end)
    |> Enum.sum()
    
    # Ensure we always return a float
    case result do
      0 -> 0.0
      other -> other
    end
  end

  defp calculate_direct_total(splits) do
    result = splits
    |> Enum.map(fn split -> 
      case split.store_amount do
        nil -> 0.0
        amount -> Decimal.to_float(amount)
      end
    end)
    |> Enum.sum()
    
    # Ensure we always return a float
    case result do
      0 -> 0.0
      other -> other
    end
  end

  defp calculate_platform_total(splits) do
    result = splits
    |> Enum.map(fn split ->
      case split.platform_fee_amount do
        nil -> 0.0
        amount -> Decimal.to_float(amount)
      end
    end)
    |> Enum.sum()
    
    # Ensure we always return a float
    case result do
      0 -> 0.0
      other -> other
    end
  end

  defp calculate_pre_kyc_donation_total(escrow_splits) do
    result = escrow_splits
    |> Enum.map(fn split ->
      case split.platform_fee_amount do
        nil -> 0.0
        amount -> Decimal.to_float(amount)
      end
    end)
    |> Enum.sum()
    
    # Ensure we always return a float
    case result do
      0 -> 0.0
      other -> other
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Escrow Dashboard</h1>
        <p class="text-gray-600 mt-2">Track funds held in escrow vs direct transfers</p>
      </div>

      <%= if @loading do %>
        <div class="flex justify-center items-center py-12">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
          <span class="ml-2 text-gray-600">Loading escrow data...</span>
        </div>
      <% else %>

      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <!-- Shomp Holdings (Platform Revenue) -->
        <div class="bg-green-50 border border-green-200 rounded-lg p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                </svg>
              </div>
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-medium text-gray-900">Shomp Holdings</h3>
              <p class="text-sm text-gray-600">Pure platform returns</p>
              <p class="text-2xl font-bold text-green-600">$<%= :erlang.float_to_binary(@escrow_data.platform_total, decimals: 2) %></p>
            </div>
          </div>
        </div>

        <!-- Shomp Pre-KYC Donation Hold -->
        <div class="bg-purple-50 border border-purple-200 rounded-lg p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                </svg>
              </div>
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-medium text-gray-900">Pre-KYC Donation Hold</h3>
              <p class="text-sm text-gray-600">Platform fees from escrow</p>
              <p class="text-2xl font-bold text-purple-600">$<%= :erlang.float_to_binary(@escrow_data.pre_kyc_donation_total, decimals: 2) %></p>
            </div>
          </div>
        </div>

        <!-- Escrow Holdings -->
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-yellow-100 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                </svg>
              </div>
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-medium text-gray-900">Escrow Holdings</h3>
              <p class="text-sm text-gray-600">Store returns entrusted to Shomp</p>
              <p class="text-2xl font-bold text-yellow-600">$<%= :erlang.float_to_binary(@escrow_data.escrow_total, decimals: 2) %></p>
              <p class="text-xs text-gray-500"><%= @escrow_data.total_escrow_stores %> stores pending KYC</p>
            </div>
          </div>
        </div>

        <!-- Direct Transfers -->
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
                </svg>
              </div>
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-medium text-gray-900">Direct Transfers</h3>
              <p class="text-sm text-gray-600">Completed KYC stores</p>
              <p class="text-2xl font-bold text-blue-600">$<%= :erlang.float_to_binary(@escrow_data.direct_total, decimals: 2) %></p>
              <p class="text-xs text-gray-500"><%= @escrow_data.total_direct_stores %> stores with KYC</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Escrow Details Table -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Escrow Details</h3>
          <p class="text-sm text-gray-600">Funds held in escrow until KYC completion</p>
        </div>
        
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Store</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Order ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Store Amount</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Platform Fee (Donation)</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Total</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for split <- @escrow_data.escrow_splits do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    Store #<%= split.store_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= split.universal_order_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= case split.store_amount do
                      nil -> "0.00"
                      amount -> :erlang.float_to_binary(Decimal.to_float(amount), decimals: 2)
                    end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= case split.platform_fee_amount do
                      nil -> "0.00"
                      amount -> :erlang.float_to_binary(Decimal.to_float(amount), decimals: 2)
                    end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= case split.total_amount do
                      nil -> "0.00"
                      amount -> :erlang.float_to_binary(Decimal.to_float(amount), decimals: 2)
                    end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= Calendar.strftime(split.inserted_at, "%m/%d/%Y") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      Escrow
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
      <% end %>
    </div>
    """
  end
end
