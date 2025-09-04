defmodule ShompWeb.StoreLive.MyStores do
  use ShompWeb, :live_view

  alias Shomp.Stores
  alias Shomp.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # If user doesn't have a tier, redirect to tier selection
    if is_nil(user.tier_id) do
      {:ok, push_navigate(socket, to: ~p"/users/tier-selection")}
    else
      stores = Stores.list_stores_by_user(user.id)
      limits = Accounts.check_user_limits(user)
      
      {:ok, 
       assign(socket, 
         stores: stores,
         limits: limits,
         page_title: "My Stores"
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">My Stores</h1>
            <p class="text-gray-600 mt-2">
              Manage your digital marketplace stores 
              (<%= @limits.store_count %>/<%= @limits.store_limit %> stores used)
            </p>
          </div>
          <div class="flex space-x-3">
            <%= if @limits.can_create_store do %>
              <.link 
                navigate={~p"/stores/new"} 
                class="btn btn-primary"
              >
                Create New Store
              </.link>
            <% else %>
              <div class="tooltip" data-tip="You've reached your tier's store limit. Upgrade to create more stores.">
                <button class="btn btn-primary btn-disabled" disabled>
                  Create New Store
                </button>
              </div>
              <.link 
                navigate={~p"/users/tier-upgrade"} 
                class="btn btn-outline"
              >
                Upgrade Plan
              </.link>
            <% end %>
          </div>
        </div>

        <%= if Enum.empty?(@stores) do %>
          <div class="text-center py-16">
            <div class="mx-auto h-24 w-24 text-gray-300 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No stores yet</h3>
            <p class="text-gray-500 mb-6">Get started by creating your first store to sell digital products.</p>
            <%= if @limits.can_create_store do %>
              <.link 
                navigate={~p"/stores/new"} 
                class="btn btn-primary"
              >
                Create Your First Store
              </.link>
            <% else %>
              <div class="space-y-4">
                <p class="text-amber-600 font-medium">You've reached your tier's store limit</p>
                <.link 
                  navigate={~p"/users/tier-upgrade"} 
                  class="btn btn-primary"
                >
                  Upgrade Plan to Create Stores
                </.link>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            <%= for store <- @stores do %>
              <div class="bg-white rounded-lg shadow-md border border-gray-200 hover:shadow-lg transition-shadow duration-200">
                <div class="p-6">
                  <div class="flex items-start justify-between mb-4">
                    <h3 class="text-xl font-semibold text-gray-900">
                      <%= store.name %>
                    </h3>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Active
                    </span>
                  </div>
                  
                  <p class="text-gray-600 mb-4 line-clamp-3">
                    <%= if store.description && String.length(store.description) > 0 do %>
                      <%= store.description %>
                    <% else %>
                      No description provided yet.
                    <% end %>
                  </p>
                  
                  <div class="flex items-center justify-between text-sm text-gray-500 mb-4">
                    <span>Created <%= Calendar.strftime(store.inserted_at, "%B %d, %Y") %></span>
                    <span class="text-blue-600 font-medium">@<%= store.slug %></span>
                  </div>
                  
                  <div class="flex space-x-2">
                    <.link 
                      navigate={~p"/stores/#{store.slug}"} 
                      class="btn btn-outline btn-sm flex-1"
                    >
                      View Store
                    </.link>
                    <.link 
                      navigate={~p"/dashboard/store"} 
                      class="btn btn-primary btn-sm flex-1"
                    >
                      Manage
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
          <div class="mt-8 text-center">
            <%= if @limits.can_create_store do %>
              <.link 
                navigate={~p"/stores/new"} 
                class="btn btn-outline"
              >
                Create Another Store
              </.link>
            <% else %>
              <div class="space-y-4">
                <p class="text-gray-500">
                  You've reached your tier's store limit (<%= @limits.store_count %>/<%= @limits.store_limit %> stores).
                </p>
                <.link 
                  navigate={~p"/users/tier-upgrade"} 
                  class="btn btn-primary"
                >
                  Upgrade Plan for More Stores
                </.link>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
