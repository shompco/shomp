defmodule ShompWeb.AdminLive.Users do
  use ShompWeb, :live_view
  import Ecto.Query, warn: false
  alias Shomp.Accounts
  alias Phoenix.PubSub

  @page_title "User Management - Admin Dashboard"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && 
       socket.assigns.current_scope.user.email == @admin_email do
      
      # Subscribe to PubSub channels for real-time updates
      if connected?(socket) do
        PubSub.subscribe(Shomp.PubSub, "admin:users")
      end

      {:ok, 
       socket 
       |> assign(:page_title, @page_title)
       |> assign(:users, list_users())
       |> assign(:total_users, count_users())
       |> assign(:search_term, "")
       |> assign(:filter_role, "all")}
    else
      {:ok, 
       socket 
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_info(%{event: "user_registered", payload: user}, socket) do
    {:noreply, socket |> assign(:users, list_users()) |> assign(:total_users, count_users())}
  end

  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, 
     socket 
     |> assign(:search_term, search_term)
     |> assign(:users, search_users(search_term, socket.assigns.filter_role))}
  end

  def handle_event("filter_role", %{"role" => role}, socket) do
    {:noreply, 
     socket 
     |> assign(:filter_role, role)
     |> assign(:users, search_users(socket.assigns.search_term, role))}
  end

  defp count_users do
    Shomp.Repo.aggregate(Shomp.Accounts.User, :count, :id)
  end

  defp list_users do
    Shomp.Repo.all(
      from u in Shomp.Accounts.User,
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
  end

  defp search_users(search_term, filter_role) do
    base_query = from u in Shomp.Accounts.User

    base_query = if search_term != "" do
      base_query
      |> where([u], ilike(u.username, ^"%#{search_term}%") or 
                       ilike(u.name, ^"%#{search_term}%") or 
                       ilike(u.email, ^"%#{search_term}%"))
    else
      base_query
    end

    base_query = if filter_role != "all" do
      base_query
      |> where([u], u.role == ^filter_role)
    else
      base_query
    end

    Shomp.Repo.all(
      base_query
      |> order_by([u], [desc: u.inserted_at])
      |> select([u], %{
        id: u.id,
        email: u.email,
        username: u.username,
        name: u.name,
        role: u.role,
        verified: u.verified,
        confirmed_at: u.confirmed_at,
        inserted_at: u.inserted_at,
        updated_at: u.updated_at
      })
    )
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <div class="flex justify-between items-center mb-4">
          <div>
            <h1 class="text-3xl font-bold mb-2">User Management</h1>
            <p class="text-base-content/70">Manage user accounts and monitor platform activity</p>
          </div>
          <a href={~p"/admin"} class="btn btn-outline">
            ← Back to Dashboard
          </a>
        </div>

        <!-- Stats -->
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-primary">👥</div>
            <div class="stat-title">Total Users</div>
            <div class="stat-value text-primary"><%= @total_users %></div>
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
                placeholder="Search by username, name, or email..." 
                class="input input-bordered flex-1" />
              <button type="submit" class="btn btn-primary">Search</button>
            </form>
          </div>
          
          <div class="flex gap-2">
            <select 
              phx-change="filter_role" 
              name="role" 
              class="select select-bordered">
              <option value="all" selected={@filter_role == "all"}>All Roles</option>
              <option value="user" selected={@filter_role == "user"}>User</option>
              <option value="admin" selected={@filter_role == "admin"}>Admin</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Users Table -->
      <div class="bg-base-100 rounded-lg shadow overflow-hidden">
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>User</th>
                <th>Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Joined</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for user <- @users do %>
                <tr>
                  <td>
                    <div class="flex items-center space-x-3">
                      <div class="avatar placeholder">
                        <div class="bg-neutral text-neutral-content rounded-full w-12">
                          <span class="text-lg"><%= String.first(user.username) %></span>
                        </div>
                      </div>
                      <div>
                        <div class="font-bold"><%= user.username %></div>
                        <div class="text-sm opacity-50"><%= user.name %></div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <div class="font-medium"><%= user.email %></div>
                    </div>
                  </td>
                  <td>
                    <span class={[
                      "badge",
                      if(user.role == "admin", do: "badge-error", else: "badge-outline")
                    ]}>
                      <%= user.role %>
                    </span>
                  </td>
                  <td>
                    <div class="flex items-center gap-2">
                      <%= if user.verified do %>
                        <span class="badge badge-success badge-sm">Verified</span>
                      <% else %>
                        <span class="badge badge-warning badge-sm">Unverified</span>
                      <% end %>
                      
                      <%= if user.confirmed_at do %>
                        <span class="badge badge-success badge-sm">Confirmed</span>
                      <% else %>
                        <span class="badge badge-error badge-sm">Unconfirmed</span>
                      <% end %>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <div><%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %></div>
                      <div class="opacity-50"><%= Calendar.strftime(user.inserted_at, "%I:%M %p") %></div>
                    </div>
                  </td>
                  <td>
                    <div class="flex gap-2">
                      <button class="btn btn-xs btn-outline">View</button>
                      <button class="btn btn-xs btn-outline">Edit</button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        
        <%= if Enum.empty?(@users) do %>
          <div class="text-center py-12">
            <div class="text-6xl mb-4">👥</div>
            <h3 class="text-lg font-semibold mb-2">No users found</h3>
            <p class="text-base-content/70">
              <%= if @search_term != "" or @filter_role != "all" do %>
                Try adjusting your search criteria or filters.
              <% else %>
                No users have registered yet.
              <% end %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
