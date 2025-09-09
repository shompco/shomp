defmodule ShompWeb.AdminLive.MerchantEscrow do
  use ShompWeb, :live_view

  alias Shomp.EscrowTransfers
  alias Shomp.Stores
  alias Shomp.Stores.StoreKYCContext

  def mount(_params, _session, socket) do
    {:ok, assign(socket, load_merchant_data())}
  end

  def handle_info(_msg, socket) do
    {:noreply, assign(socket, load_merchant_data())}
  end

  def handle_event("release_escrow", %{"store_id" => store_id}, socket) do
    case EscrowTransfers.release_escrow_funds(store_id) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully transferred $#{result.amount} to merchant (updated #{result.splits_updated} payment splits)")
         |> assign(load_merchant_data())}
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to release escrow: #{reason}")
         |> assign(load_merchant_data())}
    end
  end

  defp load_merchant_data do
    merchants_with_escrow = EscrowTransfers.list_stores_with_escrow()
    
    # Get detailed info for each merchant
    merchants_with_details = Enum.map(merchants_with_escrow, fn merchant ->
      store = Stores.get_store!(merchant.store_id)
      kyc = StoreKYCContext.get_kyc_by_store_id(merchant.store_id)
      
      %{
        store: store,
        kyc: kyc,
        total_escrow: merchant.total_escrow,
        split_count: merchant.split_count,
        latest_split: merchant.latest_split,
        kyc_status: get_kyc_status(kyc),
        can_transfer: can_transfer_funds?(kyc)
      }
    end)
    
    %{merchants: merchants_with_details}
  end

  defp get_kyc_status(nil), do: "not_started"
  defp get_kyc_status(kyc) do
    case kyc.status do
      "approved" -> "completed"
      "pending" -> "pending"
      "rejected" -> "rejected"
      _ -> "pending"
    end
  end

  defp can_transfer_funds?(nil), do: false
  defp can_transfer_funds?(kyc), do: kyc.status == "approved" && !is_nil(kyc.stripe_account_id)

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <h1 class="text-3xl font-bold mb-6">Merchant Escrow Dashboard</h1>
      
      <div class="bg-base-100 rounded-lg shadow p-6">
        <h2 class="text-2xl font-semibold mb-4">Merchants with Pending Balances</h2>
        
        <%= if Enum.empty?(@merchants) do %>
          <p class="text-gray-500">No merchants with pending escrow funds.</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="table w-full">
              <thead>
                <tr>
                  <th>Store Name</th>
                  <th>Owner</th>
                  <th>Balance</th>
                  <th>KYC Status</th>
                  <th>Payment Splits</th>
                  <th>Latest Sale</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for merchant <- @merchants do %>
                  <tr>
                    <td>
                      <div class="font-semibold"><%= merchant.store.name %></div>
                      <div class="text-sm text-gray-500">ID: <%= merchant.store.store_id %></div>
                    </td>
                    <td>
                      <div><%= merchant.store.user.name %></div>
                      <div class="text-sm text-gray-500"><%= merchant.store.user.email %></div>
                    </td>
                    <td>
                      <div class="text-lg font-bold text-green-600">
                        $<%= :erlang.float_to_binary(merchant.total_escrow, decimals: 2) %>
                      </div>
                    </td>
                    <td>
                      <.kyc_badge status={merchant.kyc_status} />
                    </td>
                    <td>
                      <div class="text-center">
                        <div class="font-semibold"><%= merchant.split_count %></div>
                        <div class="text-sm text-gray-500">transactions</div>
                      </div>
                    </td>
                    <td>
                      <%= if merchant.latest_split do %>
                        <div class="text-sm">
                          <%= Calendar.strftime(merchant.latest_split.inserted_at, "%b %d, %Y") %>
                        </div>
                        <div class="text-xs text-gray-500">
                          <%= Calendar.strftime(merchant.latest_split.inserted_at, "%I:%M %p") %>
                        </div>
                      <% else %>
                        <span class="text-gray-400">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if merchant.can_transfer do %>
                        <button
                          phx-click="release_escrow"
                          phx-value-store_id={merchant.store.id}
                          class="btn btn-primary btn-sm"
                          data-confirm={"Transfer $#{:erlang.float_to_binary(merchant.total_escrow, decimals: 2)} to this merchant?"}
                        >
                          Transfer $<%= :erlang.float_to_binary(merchant.total_escrow, decimals: 2) %>
                        </button>
                      <% else %>
                        <div class="text-sm text-gray-500">
                          <%= case merchant.kyc_status do %>
                            <% "not_started" -> %>
                              KYC not started
                            <% "pending" -> %>
                              KYC pending
                            <% "rejected" -> %>
                              KYC rejected
                            <% _ -> %>
                              Cannot transfer
                          <% end %>
                        </div>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp kyc_badge(assigns) do
    ~H"""
    <span class={[
      "badge",
      case @status do
        "completed" -> "badge-success"
        "pending" -> "badge-warning"
        "rejected" -> "badge-error"
        "not_started" -> "badge-secondary"
        _ -> "badge-ghost"
      end
    ]}>
      <%= case @status do %>
        <% "completed" -> %>KYC COMPLETED
        <% "pending" -> %>PENDING
        <% "rejected" -> %>REJECTED
        <% "not_started" -> %>NOT STARTED
        <% _ -> %>UNKNOWN
      <% end %>
    </span>
    """
  end
end
