defmodule ShompWeb.StoreLive.Balance do
  use ShompWeb, :live_view

  alias Shomp.Stores.StoreKYCContext
  alias Shomp.StripeConnect

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Subscribe to Stripe updates for real-time status changes
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Shomp.PubSub, "stripe_updates")
    end

    # Get all user's stores
    user_stores = get_user_stores(user_id)

    if Enum.empty?(user_stores) do
      {:ok,
       socket
       |> put_flash(:error, "You don't have any stores yet")
       |> push_navigate(to: ~p"/new")}
    else
      # Get store KYC records for all stores
      stores_with_data = Enum.map(user_stores, fn store ->
        # Get Stripe KYC status
        kyc_record = StoreKYCContext.get_kyc_by_store_id(store.store_id)

        %{
          store: store,
          kyc_record: kyc_record
        }
      end)

      # Get Stripe balance from the first store with a Stripe account
      stripe_balance = get_stripe_balance(stores_with_data)

      # Check if we're returning from Stripe onboarding
      if params["refresh"] == "true" do
        # Find the store with a Stripe account and sync it
        store_with_stripe = Enum.find(stores_with_data, fn store_data ->
          store_data.kyc_record && store_data.kyc_record.stripe_account_id
        end)

        if store_with_stripe do
          case StripeConnect.sync_account_status(store_with_stripe.kyc_record.stripe_account_id) do
            {:ok, updated_kyc} ->
              socket = socket
                       |> put_flash(:info, "Stripe Connect status updated! Charges: #{updated_kyc.charges_enabled}, Payouts: #{updated_kyc.payouts_enabled}")
            {:error, reason} ->
              error_message = case reason do
                %Stripe.Error{message: message} -> "Stripe API error: #{message}"
                :kyc_not_found -> "KYC record not found for this Stripe account"
                _ -> "Failed to sync Stripe status: #{inspect(reason)}"
              end
              socket = socket
                       |> put_flash(:error, error_message)
          end
        end
      end

      # Get Stripe Connect dashboard URLs if user has a Stripe account
      stripe_dashboard_url = get_stripe_dashboard_url(user_stores)
      stripe_test_dashboard_url = get_stripe_test_dashboard_url(user_stores)
      stripe_balance = get_stripe_balance(stores_with_data)

      socket = socket
               |> assign(:stores_with_data, stores_with_data)
               |> assign(:stripe_dashboard_url, stripe_dashboard_url)
               |> assign(:stripe_test_dashboard_url, stripe_test_dashboard_url)
               |> assign(:stripe_balance, stripe_balance)
               |> assign(:page_title, "Store Balance")

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Store Balances</h1>
          <p class="text-lg text-gray-600 mt-2">Access your Stripe dashboard from here</p>
        </div>

        <!-- Balance Message -->
        <div class="mb-8 text-center">
          <p class="text-lg text-gray-600">Go to Stripe to see your earnings</p>
        </div>

        <!-- Stripe Connect Status Info Box -->
        <%= if has_verified_stripe_account?(@stores_with_data) do %>
          <div class="mb-8 bg-green-50 border border-green-200 rounded-lg p-4">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-green-800">
                  Stripe Connect Verified
                </h3>
                <div class="mt-1 text-sm text-green-700">
                  <p>Your account is ready to receive payouts and process payments.</p>
                </div>
              </div>
            </div>
          </div>
        <% else %>
          <!-- Stripe Connect Onboarding Button -->
          <div class="mb-8 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-yellow-800">
                    Stripe Connect Required
                  </h3>
                  <div class="mt-1 text-sm text-yellow-700">
                    <p>Complete Stripe Connect onboarding to receive payouts and process payments.</p>
                  </div>
                </div>
              </div>
              <div>
                <button
                  phx-click="start_stripe_onboarding"
                  phx-value-store_id={get_first_store_id(@stores_with_data)}
                  class="btn btn-primary">
                  Start Stripe Onboarding
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Stripe Connect Dashboard Links -->
        <%= if @stripe_dashboard_url do %>
          <div class="mb-8 bg-white shadow rounded-lg">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-medium text-gray-900">Stripe Connect Dashboard</h2>
            </div>
            <div class="px-6 py-6">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm text-gray-600 mb-2">
                    Access your Stripe Connect dashboard to manage payouts, view transactions, and update your account details.
                  </p>
                  <p class="text-xs text-gray-500">
                    You can view detailed transaction history, manage bank accounts, and track payouts.
                  </p>
                </div>
                <div class="flex space-x-3">
                  <a
                    href={@stripe_dashboard_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="btn btn-primary">
                    Open Stripe Dashboard
                  </a>
                  <%= if @stripe_test_dashboard_url do %>
                    <a
                      href={@stripe_test_dashboard_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="btn bg-orange-500 hover:bg-orange-600 text-white border-orange-500 hover:border-orange-600">
                      Open Test Dashboard
                    </a>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Stores Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6 mb-8">
          <%= for store_data <- @stores_with_data do %>
            <div class="bg-white shadow rounded-lg">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-medium text-gray-900"><%= store_data.store.name %></h3>
                <p class="text-sm text-gray-500"><%= store_data.store.store_id %></p>
              </div>

              <div class="px-6 py-6 space-y-4">
                <!-- Lifetime Earnings -->
                <div class="text-center py-4 border-t border-gray-200">
                  <div class="text-2xl font-bold text-blue-600">
                    $<%= Decimal.to_string(get_store_lifetime_earnings(store_data.store.store_id)) %>
                  </div>
                  <div class="text-sm text-gray-500 mt-1">Lifetime Earnings</div>
                </div>

              </div>
            </div>
          <% end %>
        </div>

        <!-- Payout Information -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Payout Information</h2>
          </div>

          <div class="px-6 py-6">
            <div class="prose prose-sm text-gray-600">
              <h3>How Payouts Work</h3>
              <ul>
                <li>Payouts are processed automatically via Stripe Connect</li>
                <li>You must complete Stripe Connect onboarding to receive payouts</li>
                <li>Once you have onboarded with Stripe you can withdraw funds from the Stripe dashboard</li>
              </ul>

              <h3>Stripe Connect Onboarding</h3>
              <ul>
                <li>Secure, Stripe-hosted onboarding process</li>
                <li>Collects all required business and banking information</li>
                <li>Automatically handles compliance and verification</li>
                <li>Required for receiving payouts</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("start_stripe_onboarding", %{"store_id" => store_id}, socket) do
    # Find the store by store_id
    store_data = Enum.find(socket.assigns.stores_with_data, fn data ->
      data.store.store_id == store_id
    end)

    if store_data do
      return_url = ShompWeb.Endpoint.url() <> "/dashboard/store/balance?refresh=true"

      case StripeConnect.get_onboarding_url(store_data.store.id, return_url) do
        {:ok, onboarding_url} ->
          {:noreply, redirect(socket, external: onboarding_url)}

        {:error, reason} ->
          error_message = case reason do
            %Stripe.Error{message: message} -> "Stripe API error: #{message}"
            _ -> "Failed to create onboarding link: #{inspect(reason)}"
          end

          {:noreply,
           socket
           |> put_flash(:error, error_message)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Store not found")}
    end
  end

  def handle_event("sync_stripe_status", %{"store_id" => store_id}, socket) do
    # Find the store by store_id
    store_data = Enum.find(socket.assigns.stores_with_data, fn data ->
      data.store.store_id == store_id
    end)

    if store_data && store_data.kyc_record && store_data.kyc_record.stripe_account_id do
      case StripeConnect.sync_account_status(store_data.kyc_record.stripe_account_id) do
        {:ok, _updated_kyc} ->
          {:noreply,
           socket
           |> put_flash(:info, "Stripe status synced successfully")}

        {:error, reason} ->
          error_message = case reason do
            %Stripe.Error{message: message} -> "Stripe API error: #{message}"
            _ -> "Failed to sync Stripe status: #{inspect(reason)}"
          end

          {:noreply,
           socket
           |> put_flash(:error, error_message)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "No Stripe account found for this store")}
    end
  end

  def handle_info(%{event: "stripe_updated", payload: %{kyc_id: kyc_id, store_id: _store_id, status: _status}}, socket) do
    # Update the KYC record in the list
    updated_stores_with_data = Enum.map(socket.assigns.stores_with_data, fn store_data ->
      if store_data.kyc_record && store_data.kyc_record.id == kyc_id do
        updated_kyc = StoreKYCContext.get_kyc_by_store_id(store_data.store.store_id)
        %{store_data | kyc_record: updated_kyc}
      else
        store_data
      end
    end)

    {:noreply, assign(socket, stores_with_data: updated_stores_with_data)}
  end

  def handle_info(%{event: "stripe_updated", payload: _payload}, socket) do
    # Ignore updates for other stores
    {:noreply, socket}
  end

  defp get_user_stores(user_id) do
    alias Shomp.Stores
    Stores.get_stores_by_user(user_id)
  end

  defp get_stripe_balance(stores_with_data) do
    # Find the first store with a Stripe account
    store_with_stripe = Enum.find(stores_with_data, fn store_data ->
      store_data.kyc_record && not is_nil(store_data.kyc_record.stripe_account_id)
    end)

    if store_with_stripe do
      case StripeConnect.get_account_balance(store_with_stripe.kyc_record.stripe_account_id) do
        {:ok, balance} ->
          balance
        {:error, reason} ->
          IO.puts("Failed to get Stripe balance: #{inspect(reason)}")
          # Return a default balance structure
          %{
            available: Decimal.new(0),
            pending: Decimal.new(0),
            total: Decimal.new(0)
          }
      end
    else
      nil
    end
  end

  defp get_stripe_test_balance(stores_with_data) do
    # Find the first store with a Stripe account
    store_with_stripe = Enum.find(stores_with_data, fn store_data ->
      store_data.kyc_record && not is_nil(store_data.kyc_record.stripe_account_id)
    end)

    if store_with_stripe do
      case StripeConnect.get_test_account_balance(store_with_stripe.kyc_record.stripe_account_id) do
        {:ok, balance} ->
          balance
        {:error, reason} ->
          IO.puts("Failed to get Stripe test balance: #{inspect(reason)}")
          # Return a default balance structure
          %{
            available: Decimal.new(0),
            pending: Decimal.new(0),
            total: Decimal.new(0)
          }
      end
    else
      nil
    end
  end

  defp get_stripe_dashboard_url(user_stores) do
    # Find the first store with a Stripe account
    store_with_stripe = Enum.find(user_stores, fn store ->
      case StoreKYCContext.get_kyc_by_store_id(store.store_id) do
        nil -> false
        kyc -> not is_nil(kyc.stripe_account_id)
      end
    end)

    if store_with_stripe do
      kyc = StoreKYCContext.get_kyc_by_store_id(store_with_stripe.store_id)
      case StripeConnect.get_dashboard_url(kyc.stripe_account_id) do
        {:ok, url} -> url
        {:error, _} -> nil
      end
    else
      nil
    end
  end

  defp get_stripe_test_dashboard_url(user_stores) do
    # Find the first store with a Stripe account
    store_with_stripe = Enum.find(user_stores, fn store ->
      case StoreKYCContext.get_kyc_by_store_id(store.store_id) do
        nil -> false
        kyc -> not is_nil(kyc.stripe_account_id)
      end
    end)

    if store_with_stripe do
      kyc = StoreKYCContext.get_kyc_by_store_id(store_with_stripe.store_id)
      case StripeConnect.get_test_dashboard_url(kyc.stripe_account_id) do
        {:ok, url} -> url
        {:error, _} -> nil
      end
    else
      nil
    end
  end

  defp has_verified_stripe_account?(stores_with_data) do
    Enum.any?(stores_with_data, fn store_data ->
      store_data.kyc_record &&
      store_data.kyc_record.stripe_account_id &&
      store_data.kyc_record.charges_enabled &&
      store_data.kyc_record.payouts_enabled &&
      store_data.kyc_record.onboarding_completed
    end)
  end

  defp get_store_lifetime_earnings(store_id) do
    # Get total earnings for this store from payments
    alias Shomp.Payments

    case Payments.get_store_total_earnings(store_id) do
      {:ok, total} -> total
      {:error, _} -> Decimal.new(0)
    end
  end

  defp get_first_store_id(stores_with_data) do
    case stores_with_data do
      [%{store: %{store_id: store_id}} | _] -> store_id
      [] -> nil
    end
  end
end
