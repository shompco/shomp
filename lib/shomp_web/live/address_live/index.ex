defmodule ShompWeb.AddressLive.Index do
  use ShompWeb, :live_view

  alias Shomp.Addresses

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.header>
            Address Management
            <:subtitle>Manage your billing and shipping addresses</:subtitle>
            <:actions>
              <.link href={~p"/dashboard/addresses/new"} class="btn btn-primary">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
                Add New Address
              </.link>
            </:actions>
          </.header>
        </div>

        <!-- Address Statistics -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div class="bg-base-100 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="w-8 h-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-base-content/70">Shipping Addresses</p>
                <p class="text-2xl font-semibold text-base-content"><%= length(@shipping_addresses) %></p>
              </div>
            </div>
          </div>

          <div class="bg-base-100 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="w-8 h-8 text-info" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-base-content/70">Billing Addresses</p>
                <p class="text-2xl font-semibold text-base-content"><%= length(@billing_addresses) %></p>
              </div>
            </div>
          </div>
        </div>

        <!-- Shipping Addresses -->
        <div class="bg-base-100 shadow rounded-lg mb-8">
          <div class="px-6 py-4 border-b border-base-300">
            <h2 class="text-lg font-medium text-base-content flex items-center">
              <svg class="w-5 h-5 mr-2 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
              Shipping Addresses
            </h2>
          </div>
          
          <%= if Enum.empty?(@shipping_addresses) do %>
            <div class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-base-content">No shipping addresses</h3>
              <p class="mt-1 text-sm text-base-content/70">Add a shipping address for physical products.</p>
              <div class="mt-6">
                <.link href={~p"/dashboard/addresses/new?type=shipping"} class="btn btn-primary">
                  Add Shipping Address
                </.link>
              </div>
            </div>
          <% else %>
            <div class="p-6">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%= for address <- @shipping_addresses do %>
                  <div class="border border-base-300 rounded-lg p-4 hover:bg-base-200 transition-colors">
                    <div class="flex items-start justify-between mb-3">
                      <div>
                        <h3 class="font-medium text-base-content">
                          <%= address.name %>
                          <%= if address.is_default do %>
                            <span class="badge badge-primary badge-sm ml-2">Default</span>
                          <% end %>
                        </h3>
                        <%= if address.label do %>
                          <p class="text-sm text-base-content/70"><%= address.label %></p>
                        <% end %>
                      </div>
                      <div class="flex items-center space-x-2">
                        <%= if not address.is_default do %>
                          <button 
                            phx-click="set_default"
                            phx-value-address_id={address.id}
                            class="btn btn-xs btn-outline"
                          >
                            Set Default
                          </button>
                        <% end %>
                        <.link href={~p"/dashboard/addresses/#{address.id}/edit"} class="btn btn-xs btn-outline">
                          Edit
                        </.link>
                        <button 
                          phx-click="delete_address"
                          phx-value-address_id={address.id}
                          class="btn btn-xs btn-error"
                          data-confirm="Are you sure you want to delete this address?"
                        >
                          Delete
                        </button>
                      </div>
                    </div>
                    <div class="text-sm text-base-content/80">
                      <p><%= address.street %></p>
                      <p><%= address.city %>, <%= address.state %> <%= address.zip_code %></p>
                      <p><%= address.country %></p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Billing Addresses -->
        <div class="bg-base-100 shadow rounded-lg">
          <div class="px-6 py-4 border-b border-base-300">
            <h2 class="text-lg font-medium text-base-content flex items-center">
              <svg class="w-5 h-5 mr-2 text-info" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              Billing Addresses
            </h2>
          </div>
          
          <%= if Enum.empty?(@billing_addresses) do %>
            <div class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-base-content">No billing addresses</h3>
              <p class="mt-1 text-sm text-base-content/70">Add a billing address for your orders.</p>
              <div class="mt-6">
                <.link href={~p"/dashboard/addresses/new?type=billing"} class="btn btn-primary">
                  Add Billing Address
                </.link>
              </div>
            </div>
          <% else %>
            <div class="p-6">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%= for address <- @billing_addresses do %>
                  <div class="border border-base-300 rounded-lg p-4 hover:bg-base-200 transition-colors">
                    <div class="flex items-start justify-between mb-3">
                      <div>
                        <h3 class="font-medium text-base-content">
                          <%= address.name %>
                          <%= if address.is_default do %>
                            <span class="badge badge-primary badge-sm ml-2">Default</span>
                          <% end %>
                        </h3>
                        <%= if address.label do %>
                          <p class="text-sm text-base-content/70"><%= address.label %></p>
                        <% end %>
                      </div>
                      <div class="flex items-center space-x-2">
                        <%= if not address.is_default do %>
                          <button 
                            phx-click="set_default"
                            phx-value-address_id={address.id}
                            class="btn btn-xs btn-outline"
                          >
                            Set Default
                          </button>
                        <% end %>
                        <.link href={~p"/dashboard/addresses/#{address.id}/edit"} class="btn btn-xs btn-outline">
                          Edit
                        </.link>
                        <button 
                          phx-click="delete_address"
                          phx-value-address_id={address.id}
                          class="btn btn-xs btn-error"
                          data-confirm="Are you sure you want to delete this address?"
                        >
                          Delete
                        </button>
                      </div>
                    </div>
                    <div class="text-sm text-base-content/80">
                      <p><%= address.street %></p>
                      <p><%= address.city %>, <%= address.state %> <%= address.zip_code %></p>
                      <p><%= address.country %></p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    billing_addresses = Addresses.list_user_addresses(user.id, "billing")
    shipping_addresses = Addresses.list_user_addresses(user.id, "shipping")
    
    socket = 
      socket
      |> assign(:billing_addresses, billing_addresses)
      |> assign(:shipping_addresses, shipping_addresses)
      |> assign(:page_title, "Address Management")

    {:ok, socket}
  end

  @impl true
  def handle_event("set_default", %{"address_id" => address_id}, socket) do
    address = Addresses.get_address!(address_id)
    
    case Addresses.set_default_address(address) do
      {:ok, _updated_address} ->
        # Refresh the address lists
        user = socket.assigns.current_scope.user
        billing_addresses = Addresses.list_user_addresses(user.id, "billing")
        shipping_addresses = Addresses.list_user_addresses(user.id, "shipping")
        
        {:noreply, 
         socket
         |> put_flash(:info, "Default address updated")
         |> assign(:billing_addresses, billing_addresses)
         |> assign(:shipping_addresses, shipping_addresses)}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update default address")}
    end
  end

  @impl true
  def handle_event("delete_address", %{"address_id" => address_id}, socket) do
    address = Addresses.get_address!(address_id)
    
    case Addresses.delete_address(address) do
      {:ok, _deleted_address} ->
        # Refresh the address lists
        user = socket.assigns.current_scope.user
        billing_addresses = Addresses.list_user_addresses(user.id, "billing")
        shipping_addresses = Addresses.list_user_addresses(user.id, "shipping")
        
        {:noreply, 
         socket
         |> put_flash(:info, "Address deleted successfully")
         |> assign(:billing_addresses, billing_addresses)
         |> assign(:shipping_addresses, shipping_addresses)}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete address")}
    end
  end
end
