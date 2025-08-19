defmodule ShompWeb.StoreLive.Balance do
  use ShompWeb, :live_view

  alias Shomp.Stores.StoreBalances
  alias Shomp.Stores.StoreKYCContext

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    
    # Get the user's store
    case get_user_store(user_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have a store yet")
         |> push_navigate(to: ~p"/stores/new")}

      store ->
        # Get or create store balance
        {:ok, store_balance} = StoreBalances.get_or_create_store_balance(store.store_id)
        
        # Get KYC status
        kyc_record = StoreKYCContext.get_kyc(store.store_id)
        
        socket = socket
                 |> assign(:store, store)
                 |> assign(:store_balance, store_balance)
                 |> assign(:kyc_record, kyc_record)
                 |> assign(:page_title, "Store Balance")
        
        {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Store Balance</h1>
          <p class="text-lg text-gray-600 mt-2"><%= @store.name %></p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Balance Overview -->
          <div class="bg-white shadow rounded-lg">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-medium text-gray-900">Earnings Overview</h2>
            </div>
            
            <div class="px-6 py-6 space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-600">Total Earnings</span>
                <span class="text-2xl font-bold text-green-600">
                  $<%= @store_balance.total_earnings %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-600">Pending Balance</span>
                <span class="text-xl font-semibold text-blue-600">
                  $<%= @store_balance.pending_balance %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-600">Paid Out</span>
                <span class="text-lg text-gray-900">
                  $<%= @store_balance.paid_out_balance %>
                </span>
              </div>
              
              <%= if @store_balance.last_payout_date do %>
                <div class="flex justify-between items-center">
                  <span class="text-gray-600">Last Payout</span>
                  <span class="text-sm text-gray-500">
                    <%= Calendar.strftime(@store_balance.last_payout_date, "%B %d, %Y") %>
                  </span>
                </div>
              <% end %>
            </div>
          </div>

          <!-- KYC Status -->
          <div class="bg-white shadow rounded-lg">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-medium text-gray-900">KYC Status</h2>
            </div>
            
            <div class="px-6 py-6">
              <%= if @kyc_record == nil do %>
                <!-- No KYC submitted yet -->
                <div class="text-center py-4">
                  <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-yellow-100 mb-4">
                    <svg class="h-6 w-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2z" />
                    </svg>
                  </div>
                  <h3 class="text-sm font-medium text-gray-900 mb-2">KYC Not Submitted</h3>
                  <p class="text-sm text-gray-500 mb-4">
                    You need to complete KYC verification to receive payouts.
                  </p>
                  <button class="btn btn-primary btn-sm">
                    Submit KYC Documents
                  </button>
                </div>
              <% else %>
                <%= if @kyc_record.status == "pending" do %>
                  <!-- KYC Pending -->
                  <div class="text-center py-4">
                    <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-yellow-100 mb-4">
                      <svg class="h-6 w-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                    <h3 class="text-sm font-medium text-gray-900 mb-2">KYC Pending</h3>
                    <p class="text-sm text-gray-500">
                      Your KYC documents are being reviewed.
                    </p>
                  </div>
                <% else %>
                  <%= if @kyc_record.status == "submitted" do %>
                    <!-- KYC Submitted -->
                    <div class="text-center py-4">
                      <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 mb-4">
                        <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                      </div>
                      <h3 class="text-sm font-medium text-gray-900 mb-2">KYC Submitted</h3>
                      <p class="text-sm text-gray-500">
                        Submitted on <%= Calendar.strftime(@kyc_record.submitted_at, "%B %d, %Y") %>
                      </p>
                    </div>
                  <% else %>
                    <%= if @kyc_record.status == "verified" do %>
                      <!-- KYC Verified -->
                      <div class="text-center py-4">
                        <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100 mb-4">
                          <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                          </svg>
                        </div>
                        <h3 class="text-sm font-medium text-gray-900 mb-2">KYC Verified</h3>
                        <p class="text-sm text-gray-500">
                          Verified on <%= Calendar.strftime(@kyc_record.verified_at, "%B %d, %Y") %>
                        </p>
                        <div class="mt-4 p-3 bg-green-50 rounded-lg">
                          <p class="text-sm text-green-800">
                            ✅ You're eligible for payouts!
                          </p>
                        </div>
                      </div>
                    <% else %>
                      <%= if @kyc_record.status == "rejected" do %>
                        <!-- KYC Rejected -->
                        <div class="text-center py-4">
                          <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100 mb-4">
                            <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                          </div>
                          <h3 class="text-sm font-medium text-gray-900 mb-2">KYC Rejected</h3>
                          <p class="text-sm text-gray-500 mb-2">
                            Rejected on <%= Calendar.strftime(@kyc_record.rejected_at, "%B %d, %Y") %>
                          </p>
                          <%= if @kyc_record.rejection_reason do %>
                            <p class="text-sm text-red-600 mb-4">
                              Reason: <%= @kyc_record.rejection_reason %>
                            </p>
                          <% end %>
                          <button class="btn btn-outline btn-sm">
                            Resubmit KYC
                          </button>
                        </div>
                      <% end %>
                    <% end %>
                  <% end %>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Payout Information -->
        <div class="mt-8 bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Payout Information</h2>
          </div>
          
          <div class="px-6 py-6">
            <div class="prose prose-sm text-gray-600">
              <h3>How Payouts Work</h3>
              <ul>
                <li>Payouts are processed monthly for verified stores</li>
                <li>You must complete KYC verification to receive payouts</li>
                <li>Payouts are sent via bank transfer or check</li>
                <li>Minimum payout amount: $50.00</li>
                <li>Payouts are processed within 5-7 business days</li>
              </ul>
              
              <h3>KYC Requirements</h3>
              <ul>
                <li>Valid government-issued photo ID</li>
                <li>Proof of US residency</li>
                <li>Tax identification number (SSN or EIN)</li>
                <li>Business documentation (if applicable)</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_user_store(user_id) do
    alias Shomp.Stores
    Stores.get_stores_by_user(user_id)
    |> List.first()
  end
end
