defmodule ShompWeb.UserLive.TierSelection do
  use ShompWeb, :live_view
  alias Shomp.Accounts

  def mount(_params, _session, socket) do
    tiers = Accounts.list_active_tiers()
    current_user = socket.assigns.current_scope.user
    
    # If user already has a tier, redirect to homepage
    if current_user.tier_id do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      # User is logged in but has no tier, show tier selection
      {:ok, 
       assign(socket, 
         tiers: tiers,
         page_title: "Choose Your Plan",
         selected_tier: nil
       )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-7xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-16">
          <h1 class="text-5xl font-bold text-gray-900 mb-6">
            Welcome to Shomp! 🎉
          </h1>
          <p class="text-xl text-gray-600 max-w-3xl mx-auto">
            Choose the perfect plan to start your digital marketplace journey. 
            You can always upgrade or downgrade later.
          </p>
        </div>

        <!-- Tier Cards -->
        <div class="grid md:grid-cols-3 gap-8 mb-16">
          <%= for tier <- @tiers do %>
            <div class={[
              "relative rounded-2xl border-2 p-8 bg-white shadow-lg transition-all duration-300 hover:shadow-xl",
              @selected_tier && @selected_tier.id == tier.id && "border-blue-500 ring-4 ring-blue-100",
              @selected_tier && @selected_tier.id != tier.id && "border-gray-200 opacity-75",
              !@selected_tier && "border-gray-200 hover:border-gray-300"
            ]}>
              <!-- Popular Badge -->
              <%= if tier.slug == "plus" do %>
                <div class="absolute -top-4 left-1/2 transform -translate-x-1/2">
                  <span class="bg-gradient-to-r from-purple-600 to-pink-600 text-white px-4 py-2 rounded-full text-sm font-semibold shadow-lg">
                    Most Popular
                  </span>
                </div>
              <% end %>

              <!-- Free Badge -->
              <%= if tier.slug == "free" do %>
                <div class="absolute -top-4 left-1/2 transform -translate-x-1/2">
                  <span class="bg-green-600 text-white px-4 py-2 rounded-full text-sm font-semibold shadow-lg">
                    Free Forever
                  </span>
                </div>
              <% end %>

              <div class="text-center">
                <h3 class="text-3xl font-bold text-gray-900 mb-4"><%= tier.name %></h3>
                
                <div class="mb-8">
                  <div class="text-5xl font-bold text-gray-900">
                    $<%= tier.monthly_price %>
                  </div>
                  <div class="text-lg text-gray-600">
                    <%= if Decimal.eq?(tier.monthly_price, Decimal.new("0")) do %>
                      Free forever
                    <% else %>
                      per month
                    <% end %>
                  </div>
                </div>
                
                <!-- Features List -->
                <ul class="text-left space-y-4 mb-8">
                  <li class="flex items-start">
                    <svg class="w-6 h-6 text-green-500 mr-3 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    <div>
                      <span class="font-semibold text-gray-900"><%= tier.store_limit %></span>
                      <span class="text-gray-600"> store<%= if tier.store_limit > 1, do: "s", else: "" %></span>
                    </div>
                  </li>
                  
                  <li class="flex items-start">
                    <svg class="w-6 h-6 text-green-500 mr-3 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    <div>
                      <span class="font-semibold text-gray-900"><%= tier.product_limit_per_store %></span>
                      <span class="text-gray-600"> products per store</span>
                    </div>
                  </li>
                  
                  <%= for feature <- tier.features do %>
                    <li class="flex items-start">
                      <svg class="w-6 h-6 text-green-500 mr-3 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                      </svg>
                      <span class="text-gray-600"><%= feature %></span>
                    </li>
                  <% end %>
                </ul>

                <!-- Selection Button -->
                <button 
                  phx-click="select_tier" 
                  phx-value-tier-id={tier.id}
                  class={[
                    "w-full py-4 px-6 rounded-xl font-semibold text-lg transition-all duration-200",
                    @selected_tier && @selected_tier.id == tier.id && "bg-blue-600 text-white shadow-lg transform scale-105",
                    @selected_tier && @selected_tier.id != tier.id && "bg-gray-200 text-gray-500 cursor-not-allowed",
                    !@selected_tier && "bg-gray-900 hover:bg-gray-800 text-white hover:shadow-lg"
                  ]}>
                  <%= if @selected_tier && @selected_tier.id == tier.id do %>
                    ✓ Selected
                  <% else %>
                    Select <%= tier.name %>
                  <% end %>
                </button>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Continue Button -->
        <div class="text-center">
          <%= if @selected_tier do %>
            <div class="mb-8">
              <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 max-w-2xl mx-auto">
                <h3 class="text-lg font-semibold text-blue-900 mb-2">
                  You've selected the <span class="text-blue-600"><%= @selected_tier.name %></span> plan
                </h3>
                <p class="text-blue-700">
                  <%= if Decimal.eq?(@selected_tier.monthly_price, Decimal.new("0")) do %>
                    Start building your digital marketplace completely free!
                  <% else %>
                    Get started with <%= @selected_tier.store_limit %> stores and up to <%= @selected_tier.product_limit_per_store %> products per store.
                  <% end %>
                </p>
              </div>
            </div>
            
            <button 
              phx-click="continue_with_tier"
              class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white text-xl font-semibold py-4 px-12 rounded-xl shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200">
              Continue with <%= @selected_tier.name %> Plan →
            </button>
          <% else %>
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 max-w-2xl mx-auto">
              <p class="text-gray-600 text-lg">
                Please select a plan to continue
              </p>
            </div>
          <% end %>
        </div>

        <!-- Footer Info -->
        <div class="mt-16 text-center text-gray-500">
          <p class="text-sm">
            You can change your plan at any time in your account settings.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("select_tier", %{"tier-id" => tier_id}, socket) do
    tier = Accounts.get_tier!(tier_id)
    {:noreply, assign(socket, selected_tier: tier)}
  end

  def handle_event("continue_with_tier", _params, socket) do
    case Accounts.upgrade_user_tier(socket.assigns.current_scope.user, socket.assigns.selected_tier) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome to #{socket.assigns.selected_tier.name}! Let's get started building your marketplace.")
         |> push_navigate(to: ~p"/")}
      
      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to set your plan. Please try again.")}
    end
  end
end
