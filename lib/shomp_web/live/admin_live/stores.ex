defmodule ShompWeb.AdminLive.Stores do
  use ShompWeb, :live_view
  import Ecto.Query, warn: false
  alias Shomp.Stores
  alias Shomp.Accounts
  alias Phoenix.PubSub

  @page_title "Store Management - Admin Dashboard"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && 
       socket.assigns.current_scope.user.email == @admin_email do
      
      # Subscribe to PubSub channels for real-time updates
      if connected?(socket) do
        PubSub.subscribe(Shomp.PubSub, "admin:stores")
      end

      {:ok, 
       socket 
       |> assign(:page_title, @page_title)
       |> assign(:stores, list_stores())
       |> assign(:total_stores, count_stores())
       |> assign(:search_term, "")
       |> assign(:filter_status, "all")}
    else
      {:ok, 
       socket 
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_info(%{event: "store_created", payload: store}, socket) do
    {:noreply, socket |> assign(:stores, list_stores()) |> assign(:total_stores, count_stores())}
  end

  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, 
     socket 
     |> assign(:search_term, search_term)
     |> assign(:stores, search_stores(search_term, socket.assigns.filter_status))}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, 
     socket 
     |> assign(:filter_status, status)
     |> assign(:stores, search_stores(socket.assigns.search_term, status))}
  end

  defp count_stores do
    Shomp.Repo.aggregate(Shomp.Stores.Store, :count, :id)
  end

  defp list_stores do
    Shomp.Repo.all(
      from s in Shomp.Stores.Store,
      join: u in Shomp.Accounts.User, on: s.user_id == u.id,
      order_by: [desc: s.inserted_at],
      select: %{
        id: s.id,
        name: s.name,
        slug: s.slug,
        description: s.description,
        user_id: s.user_id,
        user_email: u.email,
        user_username: u.username,
        user_name: u.name,
        inserted_at: s.inserted_at,
        updated_at: s.updated_at
      }
    )
  end

  defp search_stores(search_term, filter_status) do
    base_query = from s in Shomp.Stores.Store,
      join: u in Shomp.Accounts.User, on: s.user_id == u.id

    base_query = if search_term != "" do
      base_query
      |> where([s, u], ilike(s.name, ^"%#{search_term}%") or 
                       ilike(s.slug, ^"%#{search_term}%") or 
                       ilike(u.username, ^"%#{search_term}%"))
    else
      base_query
    end

    # Note: Currently no status field on stores, but keeping the filter for future use
    # base_query = if filter_status != "all" do
    #   base_query
    #   |> where([s], s.status == ^filter_status)
    # else
    #   base_query
    # end

    Shomp.Repo.all(
      base_query
      |> order_by([s], [desc: s.inserted_at])
      |> select([s, u], %{
        id: s.id,
        name: s.name,
        slug: s.slug,
        description: s.description,
        user_id: s.user_id,
        user_email: u.email,
        user_username: u.username,
        user_name: u.name,
        inserted_at: s.inserted_at,
        updated_at: s.updated_at
      })
    )
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <div class="flex justify-between items-center mb-4">
          <div>
            <h1 class="text-3xl font-bold mb-2">Store Management</h1>
            <p class="text-base-content/70">Monitor and manage stores across the platform</p>
          </div>
          <a href={~p"/admin"} class="btn btn-outline">
            ← Back to Dashboard
          </a>
        </div>

        <!-- Stats -->
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-secondary">🏪</div>
            <div class="stat-title">Total Stores</div>
            <div class="stat-value text-secondary"><%= @total_stores %></div>
          </div>
        </div>
      </div>

      <!-- Search and Filters -->
      <div class="bg-base-100 rounded-lg shadow p-6 mb-8">
        <div class="flex flex-col md:flex-row gap-4">
          <div class="flex-1">
            <form phx-change="search" class="flex gap-2">
              <input 
                type="text" 
                name="search" 
                value={@search_term}
                placeholder="Search by store name, slug, or owner..." 
                class="input input-bordered flex-1" />
              <button type="submit" class="btn btn-primary">Search</button>
            </form>
          </div>
          
          <div class="flex gap-2">
            <select 
              phx-change="filter_status" 
              name="status" 
              class="select select-bordered">
              <option value="all" selected={@filter_status == "all"}>All Stores</option>
              <!-- Future: Add status options when implemented -->
            </select>
          </div>
        </div>
      </div>

      <!-- Stores Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for store <- @stores do %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="flex justify-between items-start mb-2">
                <h2 class="card-title text-lg"><%= store.name %></h2>
                <div class="badge badge-outline">@<%= store.user_username %></div>
              </div>
              
              <p class="text-base-content/70 text-sm mb-4">
                <%= if store.description && String.length(store.description) > 100 do %>
                  <%= String.slice(store.description, 0, 100) %>...
                <% else %>
                  <%= store.description || "No description" %>
                <% end %>
              </p>
              
              <div class="space-y-2 mb-4">
                <div class="flex justify-between text-sm">
                  <span class="text-base-content/70">Owner:</span>
                  <span class="font-medium"><%= store.user_name %></span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-base-content/70">Email:</span>
                  <span class="font-medium"><%= store.user_email %></span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-base-content/70">Created:</span>
                  <span class="font-medium">
                    <%= Calendar.strftime(store.inserted_at, "%b %d, %Y") %>
                  </span>
                </div>
              </div>
              
              <div class="card-actions justify-end">
                <a href={~p"/#{store.slug}"} class="btn btn-primary btn-sm">View Store</a>
                <button class="btn btn-outline btn-sm">Manage</button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
      
      <%= if Enum.empty?(@stores) do %>
        <div class="text-center py-12">
          <div class="text-6xl mb-4">🏪</div>
          <h3 class="text-lg font-semibold mb-2">No stores found</h3>
          <p class="text-base-content/70">
            <%= if @search_term != "" do %>
              Try adjusting your search criteria.
            <% else %>
              No stores have been created yet.
            <% end %>
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end
