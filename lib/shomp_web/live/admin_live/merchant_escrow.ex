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
    # Get all stores with their user association preloaded
    stores = Stores.list_stores_with_user()
    
    # Get detailed info for each store
    merchants_with_details = Enum.map(stores, fn store ->
      kyc = StoreKYCContext.get_kyc_by_store_id(store.store_id)
      
      # Get escrow data for this store
      escrow_data = get_escrow_data_for_store(store.store_id)
      
      %{
        store: store,
        kyc: kyc,
        total_escrow: escrow_data.total_escrow,
        shomp_donation_balance: escrow_data.shomp_donation_balance,
        split_count: escrow_data.split_count,
        latest_split: escrow_data.latest_split,
        kyc_status: get_kyc_status(kyc),
        can_transfer: can_transfer_funds?(kyc, escrow_data.total_escrow)
      }
    end)
    |> Enum.filter(fn merchant -> merchant.total_escrow > 0 end)  # Only show stores with escrow
    
    %{merchants: merchants_with_details}
  end

  defp get_escrow_data_for_store(store_id) do
    # Get escrow payment splits for this store
    escrow_splits = Shomp.PaymentSplits.list_escrow_payment_splits_for_store(store_id)
    
    total_escrow = escrow_splits
    |> Enum.map(fn split -> 
      case split.store_amount do
        nil -> Decimal.new(0)
        amount -> amount
      end
    end)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    
    # Calculate total Shomp donation balance from platform fees
    shomp_donation_balance = escrow_splits
    |> Enum.map(fn split -> 
      case split.platform_fee_amount do
        nil -> Decimal.new(0)
        amount -> amount
      end
    end)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    
    latest_split = escrow_splits
    |> Enum.max_by(fn split -> split.inserted_at end, fn -> nil end)
    
    %{
      total_escrow: total_escrow,
      shomp_donation_balance: shomp_donation_balance,
      split_count: length(escrow_splits),
      latest_split: latest_split
    }
  end

  defp get_kyc_status(nil), do: "not_started"
  defp get_kyc_status(kyc) do
    case kyc.status do
      "verified" -> "completed"
      "pending" -> "pending"
      "rejected" -> "rejected"
      _ -> "pending"
    end
  end

  defp can_transfer_funds?(kyc, total_escrow) do
    kyc && kyc.status == "verified" && !is_nil(kyc.stripe_account_id) && Decimal.compare(total_escrow, Decimal.new(0)) == :gt
  end

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
                  <th>Escrow Balance</th>
                  <th>Shomp Donation</th>
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
                        $<%= Decimal.to_string(merchant.total_escrow) %>
                      </div>
                    </td>
                    <td>
                      <div class="text-lg font-bold text-blue-600">
                        $<%= Decimal.to_string(merchant.shomp_donation_balance) %>
                      </div>
                      <div class="text-xs text-gray-500">to Shomp on KYC</div>
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
                          phx-value-store_id={merchant.store.store_id}
                          class="btn btn-primary btn-sm"
                          data-confirm={"Transfer $#{Decimal.to_string(merchant.total_escrow)} to this merchant?"}
                        >
                          Transfer $<%= Decimal.to_string(merchant.total_escrow) %>
                        </button>
                      <% else %>
                        <button
                          class="btn btn-disabled btn-sm opacity-50"
                          disabled
                        >
                          <%= case merchant.kyc_status do %>
                            <% "not_started" -> %>
                              KYC Not Started
                            <% "pending" -> %>
                              KYC Pending
                            <% "rejected" -> %>
                              KYC Rejected
                            <% _ -> %>
                              Cannot Transfer
                          <% end %>
                        </button>
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
