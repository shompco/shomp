defmodule ShompWeb.UserLive.TierUpgrade do
  use ShompWeb, :live_view
  alias Shomp.Accounts

  def mount(_params, _session, socket) do
    tiers = Accounts.list_active_tiers()
    current_user = socket.assigns.current_scope.user

    # Preload tier information
    user_with_tier = Shomp.Repo.preload(current_user, :tier)

    # If user doesn't have a tier, redirect to tier selection
    if !user_with_tier.tier do
      {:ok, push_navigate(socket, to: ~p"/users/tier-selection")}
    else
      limits = Accounts.check_user_limits(user_with_tier)

      {:ok,
       assign(socket,
         tiers: tiers,
         current_tier: user_with_tier.tier,
         user_limits: limits,
         page_title: "Upgrade Your Plan"
       )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-base-content mb-4">Choose Your Plan</h1>
        <p class="text-xl text-base-content/70">Upgrade to unlock more features and higher limits</p>
      </div>

      <!-- Your Store -->
      <div class="mb-12">
        <h2 class="text-2xl font-bold text-base-content mb-6 text-center">Your Store</h2>
        <div class="max-w-md mx-auto">
          <div class="bg-base-200 p-6 rounded-lg text-center">
            <h3 class="text-lg font-medium text-base-content mb-2">Products</h3>
            <p class="text-3xl font-bold text-primary">
              <%= @user_limits.product_count %> <%= if @user_limits.product_count == 1, do: "product", else: "products" %>
            </p>
          </div>
        </div>
      </div>

      <!-- Tier Cards -->
      <div class="grid md:grid-cols-3 gap-8 mb-16">
        <%= for tier <- @tiers do %>
          <div class={[
            "relative rounded-2xl border-2 p-8 bg-base-100 shadow-lg transition-all duration-300",
            tier.id == @current_tier.id && "border-primary bg-primary/10 ring-4 ring-primary/20",
            tier.id != @current_tier.id && "border-base-300 hover:border-base-content/20 hover:shadow-xl"
          ]}>
            <%= if tier.id == @current_tier.id do %>
              <div class="absolute -top-3 left-1/2 transform -translate-x-1/2">
                <span class="bg-primary text-primary-content px-3 py-1 rounded-full text-sm font-medium">
                  Current Plan
                </span>
              </div>
            <% end %>

            <!-- Popular Badge -->
            <%= if tier.slug == "plus" do %>
              <div class="absolute -top-4 right-4">
                <span class="bg-gradient-to-r from-secondary to-accent text-secondary-content px-3 py-1 rounded-full text-sm font-semibold">
                  Most Popular
                </span>
              </div>
            <% end %>

            <div class="text-center">
              <h3 class="text-2xl font-bold text-base-content mb-2"><%= tier.name %></h3>
              <div class="text-4xl font-bold text-base-content mb-4">
                $<%= tier.monthly_price %>
                <span class="text-lg font-normal text-base-content/70">/month</span>
              </div>

              <ul class="text-left space-y-3 mb-8">
                <%= if tier.slug == "free" do %>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Unlimited Products
                  </li>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Basic Support
                  </li>
                <% end %>
                <%= if tier.slug == "plus" do %>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Unlimited Products
                  </li>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Priority Support
                  </li>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Support Shomp
                  </li>
                <% end %>
                <%= if tier.slug == "pro" do %>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Unlimited Products
                  </li>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Priority Support
                  </li>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Support Shomp
                  </li>
                  <li class="flex items-center">
                    <svg class="w-5 h-5 text-success mr-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    1 of your Products Featured in Monthly Newsletter
                  </li>
                <% end %>
              </ul>

              <%= if tier.id == @current_tier.id do %>
                <button disabled class="w-full bg-base-300 text-base-content/50 py-3 px-6 rounded-lg font-medium cursor-not-allowed">
                  Current Plan
                </button>
              <% else %>
                <button
                  phx-click="upgrade_to_tier"
                  phx-value-tier-id={tier.id}
                  class="w-full bg-primary hover:bg-primary/90 text-primary-content py-3 px-6 rounded-lg font-medium transition-colors">
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
      <div class="bg-info/10 border border-info/20 rounded-lg p-6 max-w-2xl mx-auto">
        <h3 class="text-lg font-semibold text-info mb-2">Your Current Plan: <%= @current_tier.name %></h3>
        <p class="text-info">
          <%= if @current_tier.slug == "free" do %>
            You're currently on the Free plan with Unlimited Products and Basic Support.
          <% end %>
          <%= if @current_tier.slug == "plus" do %>
            You're currently on the Plus plan with Unlimited Products, Priority Support, and Support Shomp.
          <% end %>
          <%= if @current_tier.slug == "pro" do %>
            You're currently on the Pro plan with Unlimited Products, Priority Support, Support Shomp, and 1 of your Products Featured in Monthly Newsletter.
          <% end %>
        </p>
      </div>
    </div>
    """
  end

  def handle_event("upgrade_to_tier", %{"tier-id" => tier_id}, socket) do
    tier = Accounts.get_tier!(tier_id)

    case Accounts.upgrade_user_tier(socket.assigns.current_scope.user, tier) do
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
