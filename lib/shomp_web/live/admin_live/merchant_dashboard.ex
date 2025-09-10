defmodule ShompWeb.AdminLive.MerchantDashboard do
  use ShompWeb, :live_view
  import Ecto.Query, warn: false
  alias Phoenix.PubSub

  @page_title "Merchant Dashboard - Admin"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope &&
       socket.assigns.current_scope.user.email == @admin_email do

      # Subscribe to PubSub channels for real-time updates
      if connected?(socket) do
        PubSub.subscribe(Shomp.PubSub, "admin:users")
        PubSub.subscribe(Shomp.PubSub, "admin:stores")
      end

      {:ok,
       socket
       |> assign(:page_title, @page_title)
       |> load_merchant_data()}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_info(%{event: "user_registered", payload: _user}, socket) do
    {:noreply, socket |> load_merchant_data()}
  end

  def handle_info(%{event: "store_created", payload: _store}, socket) do
    {:noreply, socket |> load_merchant_data()}
  end

  def handle_event("show_user_details", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    stores = get_user_stores_with_details(user_id)

    # Get detailed store information with earnings and orders
    stores_with_details = Enum.map(stores, fn store ->
      earnings = get_store_earnings(store.store_id)
      recent_orders = get_store_recent_orders(store.store_id)

      Map.merge(store, %{
        earnings: earnings,
        recent_orders: recent_orders
      })
    end)

    {:noreply,
     socket
     |> assign(:selected_user_id, user_id)
     |> assign(:user_stores, stores_with_details)}
  end

  def handle_event("hide_user_details", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_user_id, nil)
     |> assign(:user_stores, [])}
  end

  defp load_merchant_data(socket) do
    merchants = get_merchants_with_data()

    socket
    |> assign(:merchants, merchants)
    |> assign(:total_merchants, length(merchants))
    |> assign(:selected_user_id, nil)
    |> assign(:user_stores, [])
  end

  defp get_merchants_with_data do
    # Get all users who have stores
    users = Shomp.Repo.all(
      from u in Shomp.Accounts.User,
      join: s in Shomp.Stores.Store,
      on: s.user_id == u.id,
      group_by: [u.id, u.email, u.username, u.name, u.role, u.verified, u.confirmed_at, u.inserted_at, u.updated_at],
      order_by: [desc: u.inserted_at],
      select: %{
        id: u.id,
        email: u.email,
        username: u.username,
        name: u.name,
        role: u.role,
        verified: u.verified,
        confirmed_at: u.confirmed_at,
        inserted_at: u.inserted_at,
        updated_at: u.updated_at
      }
    )

    # Enrich each user with store and Stripe data
    Enum.map(users, fn user ->
      # Get user's stores with both id and store_id
      stores = Shomp.Repo.all(
        from s in Shomp.Stores.Store,
        where: s.user_id == ^user.id,
        select: %{id: s.id, store_id: s.store_id, name: s.name, slug: s.slug}
      )

      # Get Stripe account ID from any of their stores (using integer id)
      stripe_account_id = if length(stores) > 0 do
        store_ids = Enum.map(stores, & &1.id)
        kyc = Shomp.Repo.one(
          from kyc in Shomp.Stores.StoreKYC,
          where: kyc.store_id in ^store_ids,
          select: kyc.stripe_account_id,
          limit: 1
        )
        kyc
      else
        nil
      end

      # Get product count across all stores (using string store_id)
      product_count = if length(stores) > 0 do
        store_string_ids = Enum.map(stores, & &1.store_id)
        Shomp.Repo.one(
          from p in Shomp.Products.Product,
          where: p.store_id in ^store_string_ids,
          select: count(p.id)
        ) || 0
      else
        0
      end

      # Get total earnings across all stores
      total_earnings = if length(stores) > 0 do
        store_string_ids = Enum.map(stores, & &1.store_id)
        result = Shomp.Repo.one(
          from ps in Shomp.PaymentSplits.PaymentSplit,
          where: ps.store_id in ^store_string_ids and ps.transfer_status == "succeeded",
          select: sum(ps.store_amount)
        )
        result || Decimal.new(0)
      else
        Decimal.new(0)
      end

      # Get total platform fees across all stores
      total_platform_fees = if length(stores) > 0 do
        store_string_ids = Enum.map(stores, & &1.store_id)
        result = Shomp.Repo.one(
          from ps in Shomp.PaymentSplits.PaymentSplit,
          where: ps.store_id in ^store_string_ids and ps.transfer_status == "succeeded",
          select: sum(ps.platform_fee_amount)
        )
        result || Decimal.new(0)
      else
        Decimal.new(0)
      end

      Map.merge(user, %{
        stripe_account_id: stripe_account_id,
        stores: stores,
        store_count: length(stores),
        product_count: product_count,
        total_earnings: total_earnings,
        total_platform_fees: total_platform_fees
      })
    end)
  end

  defp get_user_stores_with_details(user_id) do
    Shomp.Repo.all(
      from s in Shomp.Stores.Store,
      left_join: p in Shomp.Products.Product,
      on: p.store_id == s.store_id,
      where: s.user_id == ^user_id,
      group_by: [s.id, s.name, s.slug, s.store_id, s.inserted_at],
      select: %{
        id: s.id,
        name: s.name,
        slug: s.slug,
        store_id: s.store_id,
        product_count: count(p.id),
        created_at: s.inserted_at
      }
    )
  end

  defp get_store_earnings(store_id) do
    # Get total earnings and platform fees for this store
    Shomp.Repo.one(
      from ps in Shomp.PaymentSplits.PaymentSplit,
      where: ps.store_id == ^store_id and ps.transfer_status == "succeeded",
      select: %{
        total_earnings: sum(ps.store_amount),
        total_platform_fees: sum(ps.platform_fee_amount)
      }
    ) || %{total_earnings: Decimal.new(0), total_platform_fees: Decimal.new(0)}
  end

  defp get_store_recent_orders(store_id, limit \\ 5) do
    Shomp.Repo.all(
      from uo in Shomp.UniversalOrders.UniversalOrder,
      join: ps in Shomp.PaymentSplits.PaymentSplit,
      on: ps.universal_order_id == uo.id and ps.store_id == ^store_id,
      order_by: [desc: uo.inserted_at],
      limit: ^limit,
      select: %{
        id: uo.id,
        universal_order_id: uo.universal_order_id,
        customer_name: uo.customer_name,
        customer_email: uo.customer_email,
        total_amount: uo.total_amount,
        status: uo.status,
        created_at: uo.inserted_at
      }
    )
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <div class="flex justify-between items-center mb-4">
          <div>
            <h1 class="text-3xl font-bold mb-2">Merchant Dashboard</h1>
            <p class="text-base-content/70">Comprehensive view of merchants, stores, and earnings</p>
          </div>
          <a href={~p"/admin"} class="btn btn-outline">
            ← Back to Admin Dashboard
          </a>
        </div>

        <!-- Stats -->
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-primary">👥</div>
            <div class="stat-title">Total Merchants</div>
            <div class="stat-value text-primary"><%= @total_merchants %></div>
          </div>
        </div>
      </div>

      <!-- Merchants Table -->
      <div class="bg-base-100 rounded-lg shadow overflow-hidden">
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>Merchant</th>
                <th>Email</th>
                <th>Stripe ID</th>
                <th>Stores</th>
                <th>Products</th>
                <th>Total Earnings</th>
                <th>Shomp Donations</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for merchant <- @merchants do %>
                <tr>
                  <td>
                    <div class="flex items-center space-x-3">
                      <div class="avatar placeholder">
                        <div class="bg-neutral text-neutral-content rounded-full w-12">
                          <span class="text-lg"><%= String.first(merchant.username) %></span>
                        </div>
                      </div>
                      <div>
                        <div class="font-bold"><%= merchant.username %></div>
                        <div class="text-sm opacity-50"><%= merchant.name %></div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <div class="font-medium"><%= merchant.email %></div>
                    </div>
                  </td>
                  <td>
                    <%= if merchant.stripe_account_id do %>
                      <div class="text-xs font-mono bg-white text-black border border-gray-300 px-2 py-1 rounded">
                        <%= String.slice(merchant.stripe_account_id, 0, 20) %>...
                      </div>
                    <% else %>
                      <span class="text-gray-400 text-sm">No Stripe ID</span>
                    <% end %>
                  </td>
                  <td>
                    <div class="text-sm">
                      <div class="font-medium"><%= merchant.store_count %> stores</div>
                      <%= for store <- Enum.take(merchant.stores, 2) do %>
                        <div class="text-xs text-gray-500">• <%= store.name %></div>
                      <% end %>
                      <%= if merchant.store_count > 2 do %>
                        <div class="text-xs text-gray-500">• +<%= merchant.store_count - 2 %> more</div>
                      <% end %>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm font-medium"><%= merchant.product_count %></div>
                  </td>
                  <td>
                    <div class="text-sm font-bold text-green-600">
                      $<%= Decimal.to_string(merchant.total_earnings) %>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm font-bold text-blue-600">
                      $<%= Decimal.to_string(merchant.total_platform_fees) %>
                    </div>
                  </td>
                  <td>
                    <div class="flex gap-2">
                      <button
                        phx-click="show_user_details"
                        phx-value-user_id={merchant.id}
                        class="btn btn-xs btn-primary">
                        View Details
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%= if Enum.empty?(@merchants) do %>
          <div class="text-center py-12">
            <div class="text-6xl mb-4">👥</div>
            <h3 class="text-lg font-semibold mb-2">No merchants found</h3>
            <p class="text-base-content/70">No users have created stores yet.</p>
          </div>
        <% end %>
      </div>

      <!-- Merchant Details Modal/Section -->
      <%= if @selected_user_id do %>
        <div class="mt-8 bg-base-100 rounded-lg shadow p-6">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-bold">Merchant Store Details</h2>
            <button
              phx-click="hide_user_details"
              class="btn btn-sm btn-outline">
              Close
            </button>
          </div>

          <%= if Enum.empty?(@user_stores) do %>
            <div class="text-center py-8">
              <div class="text-4xl mb-4">🏪</div>
              <h3 class="text-lg font-semibold mb-2">No stores found</h3>
              <p class="text-base-content/70">This merchant hasn't created any stores yet.</p>
            </div>
          <% else %>
            <div class="space-y-6">
              <%= for store <- @user_stores do %>
                <div class="border rounded-lg p-4">
                  <div class="flex justify-between items-start mb-4">
                    <div>
                      <h3 class="text-lg font-semibold"><%= store.name %></h3>
                      <p class="text-sm text-gray-500">Store ID: <%= store.store_id %></p>
                      <p class="text-sm text-gray-500">Products: <%= store.product_count %></p>
                      <p class="text-sm text-gray-500">Created: <%= Calendar.strftime(store.created_at, "%b %d, %Y") %></p>
                    </div>
                    <div class="text-right">
                      <div class="text-lg font-bold text-green-600">
                        $<%= Decimal.to_string(store.earnings.total_earnings) %>
                      </div>
                      <div class="text-sm text-gray-500">Total Earnings</div>
                    </div>
                  </div>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div class="bg-blue-50 p-3 rounded">
                      <div class="text-sm text-blue-600 font-medium">Shomp Donations</div>
                      <div class="text-lg font-bold text-blue-800">
                        $<%= Decimal.to_string(store.earnings.total_platform_fees) %>
                      </div>
                    </div>
                    <div class="bg-green-50 p-3 rounded">
                      <div class="text-sm text-green-600 font-medium">Merchant Earnings</div>
                      <div class="text-lg font-bold text-green-800">
                        $<%= Decimal.to_string(store.earnings.total_earnings) %>
                      </div>
                    </div>
                  </div>

                  <!-- Recent Orders -->
                  <div class="mt-4">
                    <h4 class="font-semibold mb-2">Last 5 Orders</h4>
                    <%= if Enum.empty?(store.recent_orders) do %>
                      <p class="text-gray-500 text-sm">No orders yet</p>
                    <% else %>
                      <div class="space-y-2">
                        <%= for order <- store.recent_orders do %>
                          <div class="flex justify-between items-center py-2 px-3 bg-gray-50 rounded text-sm">
                            <div>
                              <div class="font-medium"><%= order.customer_name || "Anonymous" %></div>
                              <div class="text-gray-500"><%= order.customer_email %></div>
                            </div>
                            <div class="text-right">
                              <div class="font-medium">$<%= Decimal.to_string(order.total_amount) %></div>
                              <div class="text-gray-500"><%= Calendar.strftime(order.created_at, "%b %d") %></div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
