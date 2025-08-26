defmodule ShompWeb.AdminLive.Products do
  use ShompWeb, :live_view
  import Ecto.Query, warn: false
  alias Shomp.Products
  alias Shomp.Stores
  alias Shomp.Categories
  alias Phoenix.PubSub

  @page_title "Product Management - Admin Dashboard"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && 
       socket.assigns.current_scope.user.email == @admin_email do
      
      # Subscribe to PubSub channels for real-time updates
      if connected?(socket) do
        PubSub.subscribe(Shomp.PubSub, "admin:products")
      end

      {:ok, 
       socket 
       |> assign(:page_title, @page_title)
       |> assign(:products, list_products())
       |> assign(:total_products, count_products())
       |> assign(:search_term, "")
       |> assign(:filter_status, "all")
       |> assign(:filter_category, "all")}
    else
      {:ok, 
       socket 
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_info(%{event: "product_created", payload: product}, socket) do
    {:noreply, socket |> assign(:products, list_products()) |> assign(:total_products, count_products())}
  end

  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, 
     socket 
     |> assign(:search_term, search_term)
     |> assign(:products, search_products(search_term, socket.assigns.filter_status, socket.assigns.filter_category))}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, 
     socket 
     |> assign(:filter_status, status)
     |> assign(:products, search_products(socket.assigns.search_term, status, socket.assigns.filter_category))}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, 
     socket 
     |> assign(:filter_category, category)
     |> assign(:products, search_products(socket.assigns.search_term, socket.assigns.filter_status, category))}
  end

  defp count_products do
    Shomp.Repo.aggregate(Shomp.Products.Product, :count, :id)
  end

  defp list_products do
    Shomp.Repo.all(
      from p in Shomp.Products.Product,
      join: s in Shomp.Stores.Store, on: p.store_id == s.id,
      join: u in Shomp.Accounts.User, on: s.user_id == u.id,
      left_join: c in Shomp.Categories.Category, on: p.category_id == c.id,
      order_by: [desc: p.inserted_at],
      select: %{
        id: p.id,
        title: p.title,
        slug: p.slug,
        description: p.description,
        price: p.price,
        type: p.type,
        status: p.status,
        inventory_count: p.inventory_count,
        store_id: p.store_id,
        store_name: s.name,
        store_slug: s.slug,
        user_username: u.username,
        category_name: c.name,
        inserted_at: p.inserted_at,
        updated_at: p.updated_at
      }
    )
  end

  defp search_products(search_term, filter_status, filter_category) do
    base_query = from p in Shomp.Products.Product,
      join: s in Shomp.Stores.Store, on: p.store_id == s.id,
      join: u in Shomp.Accounts.User, on: s.user_id == u.id,
      left_join: c in Shomp.Categories.Category, on: p.category_id == c.id

    base_query = if search_term != "" do
      base_query
      |> where([p, s, u], ilike(p.title, ^"%#{search_term}%") or 
                       ilike(p.slug, ^"%#{search_term}%") or 
                       ilike(s.name, ^"%#{search_term}%") or
                       ilike(u.username, ^"%#{search_term}%"))
    else
      base_query
    end

    base_query = if filter_status != "all" do
      base_query
      |> where([p], p.status == ^filter_status)
    else
      base_query
    end

    base_query = if filter_category != "all" do
      base_query
      |> where([p, c], c.id == ^filter_category)
    else
      base_query
    end

    Shomp.Repo.all(
      base_query
      |> order_by([p], [desc: p.inserted_at])
      |> select([p, s, u, c], %{
        id: p.id,
        title: p.title,
        slug: p.slug,
        description: p.description,
        price: p.price,
        type: p.type,
        status: p.status,
        inventory_count: p.inventory_count,
        store_id: p.store_id,
        store_name: s.name,
        store_slug: s.slug,
        user_username: u.username,
        category_name: c.name,
        inserted_at: p.inserted_at,
        updated_at: p.updated_at
      })
    )
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <div class="flex justify-between items-center mb-4">
          <div>
            <h1 class="text-3xl font-bold mb-2">Product Management</h1>
            <p class="text-base-content/70">Monitor and manage products across all stores</p>
          </div>
          <a href={~p"/admin"} class="btn btn-outline">
            ← Back to Dashboard
          </a>
        </div>

        <!-- Stats -->
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-accent">📦</div>
            <div class="stat-title">Total Products</div>
            <div class="stat-value text-accent"><%= @total_products %></div>
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
                placeholder="Search by product title, store, or owner..." 
                class="input input-bordered flex-1" />
              <button type="submit" class="btn btn-primary">Search</button>
            </form>
          </div>
          
          <div class="flex gap-2">
            <select 
              phx-change="filter_status" 
              name="status" 
              class="select select-bordered">
              <option value="all" selected={@filter_status == "all"}>All Statuses</option>
              <option value="draft" selected={@filter_status == "draft"}>Draft</option>
              <option value="published" selected={@filter_status == "published"}>Published</option>
              <option value="archived" selected={@filter_status == "archived"}>Archived</option>
            </select>
            
            <select 
              phx-change="filter_category" 
              name="category" 
              class="select select-bordered">
              <option value="all" selected={@filter_category == "all"}>All Categories</option>
              <!-- Future: Add category options dynamically -->
            </select>
          </div>
        </div>
      </div>

      <!-- Products Table -->
      <div class="bg-base-100 rounded-lg shadow overflow-hidden">
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>Product</th>
                <th>Store</th>
                <th>Price</th>
                <th>Status</th>
                <th>Category</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for product <- @products do %>
                <tr>
                  <td>
                    <div class="flex items-center space-x-3">
                      <div class="avatar placeholder">
                        <div class="bg-neutral text-neutral-content rounded-full w-12">
                          <span class="text-lg">📦</span>
                        </div>
                      </div>
                      <div>
                        <div class="font-bold"><%= product.title %></div>
                        <div class="text-sm opacity-50">@<%= product.user_username %></div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <div class="font-medium"><%= product.store_name %></div>
                      <div class="opacity-50">@<%= product.user_username %></div>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm font-medium">$<%= product.price %></div>
                  </td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      case product.status do
                        "published" -> "badge-success"
                        "draft" -> "badge-warning"
                        "archived" -> "badge-error"
                        _ -> "badge-outline"
                      end
                    ]}>
                      <%= product.status %>
                    </span>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= product.category_name || "Uncategorized" %>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <div><%= Calendar.strftime(product.inserted_at, "%b %d, %Y") %></div>
                      <div class="opacity-50"><%= Calendar.strftime(product.inserted_at, "%I:%M %p") %></div>
                    </div>
                  </td>
                  <td>
                    <div class="flex gap-2">
                      <%= if product.store_slug && product.slug do %>
                        <%= if product.custom_category && product.custom_category.slug do %>
                          <a href={~p"/#{product.store_slug}/#{product.custom_category.slug}/#{product.slug}"} class="btn btn-xs btn-outline">View</a>
                        <% else %>
                          <a href={~p"/#{product.store_slug}/#{product.slug}"} class="btn btn-xs btn-outline">View</a>
                        <% end %>
                      <% else %>
                        <span class="btn btn-xs btn-outline btn-disabled">View</span>
                      <% end %>
                      <button class="btn btn-xs btn-outline">Edit</button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        
        <%= if Enum.empty?(@products) do %>
          <div class="text-center py-12">
            <div class="text-6xl mb-4">📦</div>
            <h3 class="text-lg font-semibold mb-2">No products found</h3>
            <p class="text-base-content/70">
              <%= if @search_term != "" or @filter_status != "all" or @filter_category != "all" do %>
                Try adjusting your search criteria or filters.
              <% else %>
                No products have been created yet.
              <% end %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
