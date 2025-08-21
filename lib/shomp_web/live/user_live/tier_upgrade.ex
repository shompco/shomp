defmodule ShompWeb.UserLive.TierUpgrade do
  use ShompWeb, :live_view
  alias Shomp.Accounts

  def mount(_params, _session, socket) do
    tiers = Accounts.list_active_tiers()
    current_user = socket.assigns.current_scope.user
    limits = Accounts.check_user_limits(current_user)
    
    {:ok, 
     assign(socket, 
       tiers: tiers,
       current_tier: current_user.tier,
       user_limits: limits,
       page_title: "Upgrade Your Plan"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-gray-900 mb-4">Choose Your Plan</h1>
        <p class="text-xl text-gray-600">Upgrade to unlock more features and higher limits</p>
      </div>

      <!-- Current Usage -->
      <div class="mb-12">
        <h2 class="text-2xl font-bold text-gray-900 mb-6 text-center">Your Current Usage</h2>
        <div class="grid md:grid-cols-2 gap-8 max-w-2xl mx-auto">
          <div class="bg-gray-50 p-6 rounded-lg">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Stores</h3>
            <p class="text-3xl font-bold text-blue-600">
              <%= @user_limits.store_count %> / <%= @user_limits.store_limit %>
            </p>
            <div class="mt-2">
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full" style={"width: #{min(@user_limits.store_count / @user_limits.store_limit * 100, 100)}%"}>
                </div>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 p-6 rounded-lg">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Products</h3>
            <p class="text-3xl font-bold text-blue-600">
              <%= @user_limits.product_count %> / <%= @user_limits.product_limit %>
            </p>
            <div class="mt-2">
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full" style={"width: #{min(@user_limits.product_count / @user_limits.product_limit * 100, 100)}%"}>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tier Cards -->
      <div class="grid md:grid-cols-3 gap-8 mb-16">
        <%= for tier <- @tiers do %>
          <div class={[
            "relative rounded-2xl border-2 p-8 bg-white shadow-lg transition-all duration-300",
            tier.id == @current_tier.id && "border-blue-500 bg-blue-50 ring-4 ring-blue-100",
            tier.id != @current_tier.id && "border-gray-200 hover:border-gray-300 hover:shadow-xl"
          ]}>
            <%= if tier.id == @current_tier.id do %>
              <div class="absolute -top-3 left-1/2 transform -translate-x-1/2">
                <span class="bg-blue-500 text-white px-3 py-1 rounded-full text-sm font-medium">
                  Current Plan
                </span>
              </div>
            <% end %>

            <!-- Popular Badge -->
            <%= if tier.slug == "plus" do %>
              <div class="absolute -top-4 right-4">
                <span class="bg-gradient-to-r from-purple-600 to-pink-600 text-white px-3 py-1 rounded-full text-sm font-semibold">
                  Most Popular
                </span>
              </div>
            <% end %>

            <div class="text-center">
              <h3 class="text-2xl font-bold text-gray-900 mb-2"><%= tier.name %></h3>
              <div class="text-4xl font-bold text-gray-900 mb-4">
                $<%= tier.monthly_price %>
                <span class="text-lg font-normal text-gray-600">/month</span>
              </div>
              
              <ul class="text-left space-y-3 mb-8">
                <li class="flex items-center">
                  <svg class="w-5 h-5 text-green-500 mr-3" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                  </svg>
                  <%= tier.store_limit %> stores
                </li>
                <li class="flex items-center">
                  <svg class="w-5 h-5 text-green-500 mr-3" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                  </svg>
                  <%= tier.product_limit_per_store %> products per store
                </li>
                <%= for feature <- tier.features do %>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-green-500 mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    <%= feature %>
                  </li>
                <% end %>
              </ul>

              <%= if tier.id == @current_tier.id do %>
                <button disabled class="w-full bg-gray-300 text-gray-500 py-3 px-6 rounded-lg font-medium cursor-not-allowed">
                  Current Plan
                </button>
              <% else %>
                <button 
                  phx-click="upgrade_to_tier" 
                  phx-value-tier-id={tier.id}
                  class="w-full bg-blue-600 hover:bg-blue-700 text-white py-3 px-6 rounded-lg font-medium transition-colors">
                  <%= if Decimal.gt?(tier.monthly_price, @current_tier.monthly_price) do %>
                    Upgrade to <%= tier.name %>
                  <% else %>
                    Downgrade to <%= tier.name %>
                  <% end %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Current Plan Info -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 max-w-2xl mx-auto">
        <h3 class="text-lg font-semibold text-blue-900 mb-2">Your Current Plan: <%= @current_tier.name %></h3>
        <p class="text-blue-700">
          You're currently on the <%= @current_tier.name %> plan with 
          <%= @current_tier.store_limit %> stores and up to <%= @current_tier.product_limit_per_store %> products per store.
        </p>
      </div>
    </div>
    """
  end

  def handle_event("upgrade_to_tier", %{"tier-id" => tier_id}, socket) do
    tier = Accounts.get_tier!(tier_id)
    
    case Accounts.upgrade_user_tier(socket.assigns.current_user, tier) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully #{if Decimal.gt?(tier.monthly_price, socket.assigns.current_tier.monthly_price), do: "upgraded", else: "downgraded"} to #{tier.name}!")
         |> push_navigate(to: ~p"/users/settings")}
      
      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to change tier. Please try again.")}
    end
  end
end
