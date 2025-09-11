defmodule ShompWeb.AdminLive.KYCVerification do
  use ShompWeb, :live_view
  import Ecto.Query, warn: false
  alias Shomp.Stores.StoreKYCContext
  alias Shomp.Stores
  alias Shomp.AdminLogs

  @page_title "Stripe KYC Status - Admin"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope &&
       socket.assigns.current_scope.user.email == @admin_email do

      {:ok,
       socket
       |> assign(:page_title, @page_title)
       |> assign(:selected_kyc, nil)
       |> load_kyc_data()}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_event("select_kyc", %{"kyc_id" => kyc_id}, socket) do
    kyc_id = String.to_integer(kyc_id)

    selected_kyc = Enum.find(socket.assigns.kyc_records, &(&1.id == kyc_id))

    {:noreply,
     socket
     |> assign(:selected_kyc, selected_kyc)}
  end

  def handle_event("sync_stripe_data", %{"kyc_id" => kyc_id}, socket) do
    kyc_id = String.to_integer(kyc_id)

    # Find the KYC record
    kyc = Enum.find(socket.assigns.kyc_records, &(&1.id == kyc_id))

    if kyc && kyc.stripe_account_id do
      # Sync with Stripe
      case Shomp.StripeConnect.sync_account_status(kyc.stripe_account_id) do
        {:ok, updated_kyc} ->
          # Reload the data to get the updated information
          updated_socket = load_kyc_data(socket)

          # Find the updated KYC record to show in the details
          updated_kyc_record = Enum.find(updated_socket.assigns.kyc_records, &(&1.id == kyc_id))

          {:noreply,
           updated_socket
           |> assign(:selected_kyc, updated_kyc_record)
           |> put_flash(:info, "Stripe data synced successfully! Country: #{updated_kyc.stripe_country || "Unknown"}")}

        {:error, reason} ->
          IO.puts("Sync error: #{inspect(reason)}")
          {:noreply,
           socket
           |> put_flash(:error, "Failed to sync Stripe data: #{inspect(reason)}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "No Stripe account ID found for this KYC record.")}
    end
  end

  defp load_kyc_data(socket) do
    kyc_records = StoreKYCContext.list_kyc_records_with_users()
    kyc_stats = StoreKYCContext.get_stripe_kyc_stats()

    socket
    |> assign(:kyc_records, kyc_records)
    |> assign(:kyc_stats, kyc_stats)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Stripe KYC Status</h1>
          <p class="mt-2 text-gray-600">Monitor Stripe Connect account verification status</p>
        </div>

        <!-- Stats Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">T</span>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500">Total Stores</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @kyc_stats.total %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">S</span>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500">With Stripe Account</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @kyc_stats.with_stripe_account %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-yellow-500 rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">C</span>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500">Charges Enabled</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @kyc_stats.charges_enabled %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">P</span>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500">Payouts Enabled</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @kyc_stats.payouts_enabled %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-emerald-500 rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">V</span>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500">Fully Verified</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @kyc_stats.fully_verified %></p>
              </div>
            </div>
          </div>
        </div>

        <!-- KYC Records Table -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Stripe Connect Accounts</h3>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Store</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Stripe Account</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Country</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Individual Info</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for kyc <- @kyc_records do %>
                  <tr class="hover:bg-gray-50 cursor-pointer" phx-click="select_kyc" phx-value-kyc_id={kyc.id}>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900"><%= kyc.store.name %></div>
                      <div class="text-sm text-gray-500"><%= kyc.store.store_id %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900"><%= kyc.user.name || kyc.user.username %></div>
                      <div class="text-sm text-gray-500"><%= kyc.user.email %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= if kyc.stripe_account_id do %>
                        <div class="text-sm text-gray-900 font-mono"><%= String.slice(kyc.stripe_account_id, 0, 20) %>...</div>
                      <% else %>
                        <span class="text-sm text-gray-500">No Stripe Account</span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= if kyc.stripe_country do %>
                        <div class="text-sm text-gray-900">
                          <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if kyc.stripe_country == "US", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                            <%= kyc.stripe_country %>
                          </span>
                        </div>
                      <% else %>
                        <span class="text-sm text-gray-500">Not synced</span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex flex-col space-y-1">
                        <div class="flex items-center">
                          <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if kyc.charges_enabled, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                            <%= if kyc.charges_enabled, do: "Charges ✓", else: "Charges ✗" %>
                          </span>
                        </div>
                        <div class="flex items-center">
                          <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if kyc.payouts_enabled, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                            <%= if kyc.payouts_enabled, do: "Payouts ✓", else: "Payouts ✗" %>
                          </span>
                        </div>
                        <div class="flex items-center">
                          <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if kyc.onboarding_completed, do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800"}"}>
                            <%= if kyc.onboarding_completed, do: "Onboarding ✓", else: "Onboarding ✗" %>
                          </span>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= if kyc.stripe_individual_info && map_size(kyc.stripe_individual_info) > 0 do %>
                        <div class="text-sm text-gray-900">
                          <%= kyc.stripe_individual_info["first_name"] %> <%= kyc.stripe_individual_info["last_name"] %>
                        </div>
                        <div class="text-sm text-gray-500"><%= kyc.stripe_individual_info["email"] %></div>
                      <% else %>
                        <span class="text-sm text-gray-500">No individual info</span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <%= if kyc.stripe_account_id do %>
                        <button
                          phx-click="sync_stripe_data"
                          phx-value-kyc_id={kyc.id}
                          class="btn btn-sm btn-outline btn-primary"
                        >
                          🔄 Sync with Stripe Connect
                        </button>
                      <% else %>
                        <span class="text-gray-400">No Stripe Account</span>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Selected KYC Details -->
        <%= if @selected_kyc do %>
          <div class="mt-8 bg-white shadow rounded-lg">
            <div class="px-6 py-4 border-b border-gray-200">
              <h3 class="text-lg font-medium text-gray-900">Stripe Account Details</h3>
            </div>
            <div class="px-6 py-4">
              <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-gray-500">Store</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @selected_kyc.store.name %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Store ID</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @selected_kyc.store.store_id %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Stripe Account ID</dt>
                  <dd class="mt-1 text-sm text-gray-900 font-mono"><%= @selected_kyc.stripe_account_id || "Not set" %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Country</dt>
                  <dd class="mt-1">
                    <%= if @selected_kyc.stripe_country do %>
                      <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if @selected_kyc.stripe_country == "US", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                        <%= @selected_kyc.stripe_country %>
                      </span>
                    <% else %>
                      <span class="text-sm text-gray-500">Unknown</span>
                    <% end %>
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Charges Enabled</dt>
                  <dd class="mt-1">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if @selected_kyc.charges_enabled, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                      <%= if @selected_kyc.charges_enabled, do: "Yes", else: "No" %>
                    </span>
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Payouts Enabled</dt>
                  <dd class="mt-1">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if @selected_kyc.payouts_enabled, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                      <%= if @selected_kyc.payouts_enabled, do: "Yes", else: "No" %>
                    </span>
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Onboarding Completed</dt>
                  <dd class="mt-1">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if @selected_kyc.onboarding_completed, do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800"}"}>
                      <%= if @selected_kyc.onboarding_completed, do: "Yes", else: "No" %>
                    </span>
                  </dd>
                </div>
                <%= if @selected_kyc.stripe_individual_info && map_size(@selected_kyc.stripe_individual_info) > 0 do %>
                  <div class="sm:col-span-2">
                    <dt class="text-sm font-medium text-gray-500">Individual Information</dt>
                    <dd class="mt-1 text-sm text-gray-900">
                      <div class="grid grid-cols-2 gap-4">
                        <div>
                          <strong>Name:</strong> <%= @selected_kyc.stripe_individual_info["first_name"] %> <%= @selected_kyc.stripe_individual_info["last_name"] %>
                        </div>
                        <div>
                          <strong>Email:</strong> <%= @selected_kyc.stripe_individual_info["email"] %>
                        </div>
                        <div>
                          <strong>Phone:</strong> <%= @selected_kyc.stripe_individual_info["phone"] || "Not provided" %>
                        </div>
                        <div>
                          <strong>DOB:</strong> <%= @selected_kyc.stripe_individual_info["dob"] || "Not provided" %>
                        </div>
                      </div>
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
