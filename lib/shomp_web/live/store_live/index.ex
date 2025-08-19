defmodule ShompWeb.StoreLive.Index do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Stores

  @impl true
  def mount(_params, _session, socket) do
    stores = Stores.list_stores_with_users()
    {:ok, assign(socket, stores: stores, search: "", filtered_stores: stores)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    filtered_stores = 
      if String.trim(search) == "" do
        socket.assigns.stores
      else
        socket.assigns.stores
        |> Enum.filter(fn store ->
          String.contains?(String.downcase(store.name), String.downcase(search)) or
          String.contains?(String.downcase(store.description || ""), String.downcase(search))
        end)
      end

    {:noreply, assign(socket, search: search, filtered_stores: filtered_stores)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8">
        <div class="text-center mb-12">
          <.header>
            Discover Stores
            <:subtitle>Find amazing products from creators around the world</:subtitle>
          </.header>
          
          <div class="mt-6">
            <.link
              navigate={~p"/about"}
              class="text-blue-600 hover:text-blue-800 text-sm font-medium"
            >
              About Shomp
            </.link>
          </div>
        </div>

        <div class="mb-8">
          <form phx-change="search" class="max-w-md mx-auto">
            <div class="relative">
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Search stores by name or description..."
                class="input input-bordered w-full pl-10"
                autocomplete="off"
              />
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
            </div>
          </form>
        </div>

        <%= if Enum.empty?(@filtered_stores) do %>
          <div class="text-center py-12">
            <div class="text-gray-500 text-lg mb-4">
              <%= if @search == "" do %>
                No stores found yet. Be the first to create one!
              <% else %>
                No stores match your search for "<%= @search %>"
              <% end %>
            </div>
            <%= if @current_scope do %>
              <.link
                navigate={~p"/stores/new"}
                class="btn btn-primary"
              >
                Create Your Store
              </.link>
            <% else %>
              <.link
                navigate={~p"/users/register"}
                class="btn btn-primary"
              >
                Join and Create a Store
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for store <- @filtered_stores do %>
              <div class="bg-white rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow duration-300">
                <div class="p-6">
                  <h3 class="text-xl font-semibold text-gray-900 mb-2">
                    <.link
                      navigate={~p"/#{store.slug}"}
                      class="hover:text-blue-600 transition-colors duration-200"
                    >
                      <%= store.name %>
                    </.link>
                  </h3>
                  
                  <%= if store.description do %>
                    <p class="text-gray-600 mb-4 line-clamp-3">
                      <%= store.description %>
                    </p>
                  <% end %>
                  
                  <div class="flex items-center justify-between">
                    <div class="text-sm text-gray-500">
                      by <%= store.user.email %>
                    </div>
                    <.link
                      navigate={~p"/#{store.slug}"}
                      class="btn btn-outline btn-sm"
                    >
                      Visit Store
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @current_scope do %>
          <div class="text-center mt-12">
            <.link
              navigate={~p"/stores/new"}
              class="btn btn-primary btn-lg"
            >
              Create Your Own Store
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
