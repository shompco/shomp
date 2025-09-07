defmodule ShompWeb.AdminLive.Dashboard do
  use ShompWeb, :live_view
  import Ecto.Query, warn: false
  alias Shomp.EmailSubscriptions
  alias Shomp.Stores
  alias Shomp.Products
  alias Shomp.Accounts
  alias Shomp.Uploads
  alias Shomp.AdminLogs
  alias Shomp.Stores.StoreKYCContext
  alias Shomp.Orders
  alias Shomp.SupportTickets
  alias Phoenix.PubSub

  @page_title "Admin Dashboard - Shomp"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && 
       socket.assigns.current_scope.user.email == @admin_email do
      
      # Subscribe to PubSub channels for real-time updates
      if connected?(socket) do
        PubSub.subscribe(Shomp.PubSub, "admin:stores")
        PubSub.subscribe(Shomp.PubSub, "admin:products")
        PubSub.subscribe(Shomp.PubSub, "admin:users")
        PubSub.subscribe(Shomp.PubSub, "admin:images")
        PubSub.subscribe(Shomp.PubSub, "admin:support_tickets")
      end

      {:ok, 
       socket 
       |> assign(:page_title, @page_title)
       |> load_admin_stats()}
    else
      {:ok, 
       socket 
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_info(%{event: "store_created", payload: store}, socket) do
    # Add flash message for real-time feedback
    socket = socket 
    |> put_flash(:info, "New store created: #{store.name}")
    |> load_admin_stats()
    
    {:noreply, socket}
  end

  def handle_info(%{event: "product_created", payload: product}, socket) do
    # Add flash message for real-time feedback
    socket = socket 
    |> put_flash(:info, "New product created: #{product.title}")
    |> load_admin_stats()
    
    {:noreply, socket}
  end

  def handle_info(%{event: "user_registered", payload: user}, socket) do
    # Add flash message for real-time feedback
    socket = socket 
    |> put_flash(:info, "New user registered: #{user.username || user.email}")
    |> load_admin_stats()
    
    {:noreply, socket}
  end

  def handle_info(%{event: "image_uploaded", payload: image}, socket) do
    # Add flash message for real-time feedback
    socket = socket 
    |> put_flash(:info, "New image uploaded for product #{image.product_id}")
    |> load_admin_stats()
    
    {:noreply, socket}
  end

  def handle_info(%{event: "support_ticket_created", payload: _ticket}, socket) do
    # Update support ticket count in real-time
    socket = socket 
    |> put_flash(:info, "New support ticket created")
    |> load_admin_stats()
    
    {:noreply, socket}
  end

  def handle_info(%{event: "support_ticket_updated", payload: _ticket}, socket) do
    # Update support ticket count in real-time
    socket = socket 
    |> load_admin_stats()
    
    {:noreply, socket}
  end

  defp load_admin_stats(socket) do
    socket
    |> assign(:total_users, count_users())
    |> assign(:total_stores, count_stores())
    |> assign(:total_products, count_products())
    |> assign(:total_subscriptions, EmailSubscriptions.count_email_subscriptions())
    |> assign(:active_subscriptions, EmailSubscriptions.count_active_subscriptions())
    |> assign(:kyc_stats, StoreKYCContext.get_kyc_stats())
    |> assign(:open_support_tickets, count_open_support_tickets())
    |> assign(:recent_users, list_recent_users())
    |> assign(:recent_stores, list_recent_stores())
    |> assign(:recent_products, list_recent_products())
    |> assign(:recent_orders, list_recent_orders())
    |> assign(:recent_images, list_recent_images())
    |> assign(:recent_admin_logs, list_recent_admin_logs())
  end

  defp count_users do
    # Count total users
    Shomp.Repo.aggregate(Shomp.Accounts.User, :count, :id)
  end

  defp count_stores do
    # Count total stores
    Shomp.Repo.aggregate(Shomp.Stores.Store, :count, :id)
  end

  defp count_products do
    # Count total products
    Shomp.Repo.aggregate(Shomp.Products.Product, :count, :id)
  end

  defp count_open_support_tickets do
    # Count open support tickets (not resolved or closed)
    from(t in Shomp.SupportTickets.SupportTicket,
      where: t.status in ["open", "in_progress", "waiting_customer"]
    )
    |> Shomp.Repo.aggregate(:count, :id)
  end

  defp list_recent_users do
    # Get 5 most recent users
    Shomp.Repo.all(
      from u in Shomp.Accounts.User,
      order_by: [desc: u.inserted_at],
      limit: 5,
      select: %{
        id: u.id,
        email: u.email,
        username: u.username,
        name: u.name,
        role: u.role,
        inserted_at: u.inserted_at
      }
    )
  end

  defp list_recent_stores do
    # Get 5 most recent stores with user info
    Shomp.Repo.all(
      from s in Shomp.Stores.Store,
      join: u in Shomp.Accounts.User, on: s.user_id == u.id,
      order_by: [desc: s.inserted_at],
      limit: 5,
      select: %{
        id: s.id,
        name: s.name,
        slug: s.slug,
        description: s.description,
        user_email: u.email,
        user_username: u.username,
        inserted_at: s.inserted_at
      }
    )
  end

  defp list_recent_products do
    # Get 5 most recent products with store info and custom category
    Shomp.Repo.all(
      from p in Shomp.Products.Product,
      join: s in Shomp.Stores.Store, on: p.store_id == s.store_id,
      left_join: c in Shomp.Categories.Category, on: p.custom_category_id == c.id,
      order_by: [desc: p.inserted_at],
      limit: 5,
      select: %{
        id: p.id,
        title: p.title,
        slug: p.slug,
        price: p.price,
        store_name: s.name,
        store_slug: s.slug,
        inserted_at: p.inserted_at,
        custom_category: %{
          id: c.id,
          name: c.name,
          slug: c.slug
        }
      }
    )
  end

  defp list_recent_orders do
    # Get 5 most recent orders with user and product info
    Shomp.Repo.all(
      from o in Shomp.Orders.Order,
      join: u in Shomp.Accounts.User, on: o.user_id == u.id,
      order_by: [desc: o.inserted_at],
      limit: 5,
      select: %{
        id: o.id,
        immutable_id: o.immutable_id,
        total_amount: o.total_amount,
        status: o.status,
        payment_status: o.payment_status,
        fulfillment_status: o.fulfillment_status,
        shipping_status: o.shipping_status,
        user_email: u.email,
        user_username: u.username,
        inserted_at: o.inserted_at
      }
    )
  end

  defp list_recent_admin_logs do
    # Get 10 most recent admin actions with user information
    AdminLogs.list_admin_logs_with_users(10)
  end

  defp list_recent_images do
    # Get recent image uploads from the uploads directory
    # This is a simplified approach - in production you might want to track this in the database
    upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
    products_dir = Path.join(upload_dir, "products")
    
    try do
      if File.dir?(products_dir) do
        # Get recent product directories and their images
        products_dir
        |> File.ls!()
        |> Enum.take(5)
        |> Enum.map(fn product_id ->
          product_images_dir = Path.join(products_dir, product_id)
          if File.dir?(product_images_dir) do
            try do
              images = File.ls!(product_images_dir)
              |> Enum.filter(&String.ends_with?(&1, [".png", ".jpg", ".jpeg", ".webp"]))
              |> Enum.take(3)
              
              if Enum.empty?(images) do
                %{
                  product_id: product_id,
                  images: [],
                  count: 0,
                  last_modified: nil
                }
              else
                first_image = List.first(images)
                last_modified = try do
                  stat = File.stat!(Path.join(product_images_dir, first_image))
                  # Convert File.Stat.mtime tuple to DateTime for Calendar.strftime
                  {date, time} = stat.mtime
                  DateTime.new!(NaiveDateTime.new!(date, time), "Etc/UTC")
                rescue
                  _ -> nil
                end
                
                %{
                  product_id: product_id,
                  images: images,
                  count: length(images),
                  last_modified: last_modified
                }
              end
            rescue
              _ -> 
                %{
                  product_id: product_id,
                  images: [],
                  count: 0,
                  last_modified: nil
                }
            end
          end
        end)
        |> Enum.filter(&(&1 != nil))
      else
        []
      end
    rescue
      _ -> []
    end
  end

  # Helper function to determine if an item was created recently (within last 5 minutes)
  defp is_recent?(inserted_at) do
    case inserted_at do
      nil -> false
      timestamp -> 
        five_minutes_ago = DateTime.utc_now() |> DateTime.add(-300, :second)
        DateTime.compare(timestamp, five_minutes_ago) == :gt
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">Admin Dashboard</h1>
            <p class="text-base-content/70">Monitor the Shomp platform in real-time</p>
          </div>
          <div class="flex items-center gap-2">
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
              <span class="text-sm text-green-600 font-medium">Live</span>
            </div>
            <div class="text-xs text-base-content/50">
              Real-time updates enabled
            </div>
          </div>
        </div>
      </div>

      <!-- Stats Overview -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-6 mb-8">
        <.stat_card 
          title="Total Users" 
          value={@total_users} 
          icon="👥" 
          color="primary" />
        
        <.stat_card 
          title="Total Stores" 
          value={@total_stores} 
          icon="🏪" 
          color="secondary" />
        
        <.stat_card 
          title="Total Products" 
          value={@total_products} 
          icon="📦" 
          color="accent" />
        
        <.stat_card 
          title="Open Support Tickets" 
          value={@open_support_tickets} 
          icon="🎫" 
          color="error" 
          link={~p"/admin/support"} />
        
        <.stat_card 
          title="Email Subscriptions" 
          value={@total_subscriptions} 
          icon="📧" 
          color="success" 
          link={~p"/admin/email-subscriptions"} />
        
        <.stat_card 
          title="Pending KYC" 
          value={@kyc_stats.pending} 
          icon="🆔" 
          color="warning" 
          link={~p"/admin/kyc-verification"} />
      </div>

      <!-- Recent Activity Sections -->
      <div class="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-8 mb-8">
        <!-- Recent Stores -->
        <div class="bg-base-100 rounded-lg shadow p-6">
          <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
            <span class="text-2xl">🏪</span>
            Recent Stores
          </h2>
          <div class="space-y-3">
            <%= for store <- @recent_stores do %>
              <div class="border border-base-300 rounded-lg p-3 hover:border-primary/50 transition-colors">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <h3 class="font-semibold"><%= store.name %></h3>
                      <%= if is_recent?(store.inserted_at) do %>
                        <span class="badge badge-xs badge-primary animate-pulse">New</span>
                      <% end %>
                    </div>
                    <p class="text-sm text-base-content/70">@<%= store.user_username %></p>
                    <p class="text-xs text-base-content/50">
                      <%= Calendar.strftime(store.inserted_at, "%b %d, %Y at %I:%M %p") %>
                    </p>
                  </div>
                  <%= if store.slug do %>
                    <a href={~p"/stores/#{store.slug}"} class="btn btn-xs btn-outline">View</a>
                  <% else %>
                    <span class="btn btn-xs btn-outline btn-disabled">View</span>
                  <% end %>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(@recent_stores) do %>
              <p class="text-base-content/50 text-center py-4">No stores yet</p>
            <% end %>
          </div>
        </div>

        <!-- Recent Products -->
        <div class="bg-base-100 rounded-lg shadow p-6">
          <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
            <span class="text-2xl">📦</span>
            Recent Products
          </h2>
          <div class="space-y-3">
            <%= for product <- @recent_products do %>
              <div class="border border-base-300 rounded-lg p-3 hover:border-primary/50 transition-colors">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <h3 class="font-semibold"><%= product.title %></h3>
                      <%= if is_recent?(product.inserted_at) do %>
                        <span class="badge badge-xs badge-primary animate-pulse">New</span>
                      <% end %>
                    </div>
                    <p class="text-sm text-base-content/70">$<%= product.price %></p>
                    <p class="text-xs text-base-content/50">
                      Store: <%= product.store_name %> • 
                      <%= Calendar.strftime(product.inserted_at, "%b %d, %Y at %I:%M %p") %>
                    </p>
                  </div>
                  <div class="flex gap-2">
                    <%= if product.store_slug && product.slug do %>
                      <%= if product.custom_category && Map.has_key?(product.custom_category, :slug) && product.custom_category.slug do %>
                        <a href={~p"/stores/#{product.store_slug}/#{product.custom_category.slug}/#{product.slug}"} class="btn btn-xs btn-outline">View</a>
                      <% else %>
                        <a href={~p"/stores/#{product.store_slug}/products/#{product.slug}"} class="btn btn-xs btn-outline">View</a>
                      <% end %>
                    <% else %>
                      <span class="btn btn-xs btn-outline btn-disabled">View</span>
                    <% end %>
                    
                    <a href={~p"/admin/products/#{product.id}/edit"} class="btn btn-xs btn-primary">Edit</a>
                  </div>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(@recent_products) do %>
              <p class="text-base-content/50 text-center py-4">No products yet</p>
            <% end %>
          </div>
        </div>

        <!-- Recent Orders -->
        <div class="bg-base-100 rounded-lg shadow p-6">
          <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
            <span class="text-2xl">🛒</span>
            Recent Orders
          </h2>
          <div class="space-y-3">
            <%= for order <- @recent_orders do %>
              <div class="border border-base-300 rounded-lg p-3 hover:border-primary/50 transition-colors">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <h3 class="font-semibold">Order #<%= order.immutable_id %></h3>
                      <%= if is_recent?(order.inserted_at) do %>
                        <span class="badge badge-xs badge-primary animate-pulse">New</span>
                      <% end %>
                    </div>
                    <p class="text-sm text-base-content/70">$<%= order.total_amount %></p>
                    <div class="flex items-center gap-2 mb-1">
                      <span class={[
                        "badge badge-xs",
                        case order.status do
                          "completed" -> "badge-success"
                          "processing" -> "badge-warning"
                          "pending" -> "badge-info"
                          "cancelled" -> "badge-error"
                          _ -> "badge-outline"
                        end
                      ]}>
                        <%= String.capitalize(order.status) %>
                      </span>
                    </div>
                    <p class="text-xs text-base-content/50">
                      Customer: <%= order.user_username || order.user_email %> • 
                      <%= Calendar.strftime(order.inserted_at, "%b %d, %Y at %I:%M %p") %>
                    </p>
                  </div>
                  <a href={~p"/admin/orders/#{order.immutable_id}"} class="btn btn-xs btn-outline">View</a>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(@recent_orders) do %>
              <p class="text-base-content/50 text-center py-4">No orders yet</p>
            <% end %>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
        <!-- Recent User Accounts -->
        <div class="bg-base-100 rounded-lg shadow p-6">
          <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
            <span class="text-2xl">👥</span>
            Recent User Accounts
          </h2>
          <div class="space-y-3">
            <%= for user <- @recent_users do %>
              <div class="border border-base-300 rounded-lg p-3 hover:border-primary/50 transition-colors">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <h3 class="font-semibold"><%= user.username %></h3>
                      <%= if is_recent?(user.inserted_at) do %>
                        <span class="badge badge-xs badge-primary animate-pulse">New</span>
                      <% end %>
                    </div>
                    <p class="text-sm text-base-content/70"><%= user.name %></p>
                    <p class="text-xs text-base-content/50">
                      Role: <%= user.role %> • 
                      <%= Calendar.strftime(user.inserted_at, "%b %d, %Y at %I:%M %p") %>
                    </p>
                  </div>
                  <span class="badge badge-sm badge-outline"><%= user.role %></span>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(@recent_users) do %>
              <p class="text-base-content/50 text-center py-4">No users yet</p>
            <% end %>
          </div>
        </div>

        <!-- Recent Images -->
        <div class="bg-base-100 rounded-lg shadow p-6">
          <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
            <span class="text-2xl">🖼️</span>
            Recent Images
          </h2>
          <div class="space-y-3">
            <%= for image_group <- @recent_images do %>
              <div class="border border-base-300 rounded-lg p-3">
                <div class="flex justify-between items-start">
                  <div>
                    <h3 class="font-semibold">Product #<%= image_group.product_id %></h3>
                    <p class="text-sm text-base-content/70"><%= image_group.count %> images</p>
                    <p class="text-xs text-base-content/50">
                      <%= if image_group.last_modified do %>
                        <%= Calendar.strftime(image_group.last_modified, "%b %d, %Y at %I:%M %p") %>
                      <% else %>
                        Unknown
                      <% end %>
                    </p>
                  </div>
                  <span class="badge badge-sm badge-outline"><%= image_group.count %> images</span>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(@recent_images) do %>
              <p class="text-base-content/50 text-center py-4">No images uploaded yet</p>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Recent Admin Actions -->
      <div class="bg-base-100 rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
          <span class="text-2xl">📝</span>
          Recent Admin Actions
        </h2>
        <div class="space-y-3">
          <%= for log <- @recent_admin_logs do %>
            <div class="border border-base-300 rounded-lg p-3">
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-2">
                    <span class="badge badge-xs badge-outline"><%= log.action %></span>
                    <span class="text-sm font-medium"><%= log.entity_type %></span>
                    <span class="text-xs text-base-content/50">#<%= log.entity_id %></span>
                  </div>
                  
                  <p class="text-sm text-base-content/70 mb-2"><%= log.details %></p>
                  
                  <%= if log.metadata && log.metadata["changes"] do %>
                    <div class="text-xs text-base-content/60 bg-base-200 p-2 rounded mt-2">
                      <div class="font-medium mb-1">Changes:</div>
                      <%= for {field, new_value} <- log.metadata["changes"] do %>
                        <div class="flex items-start gap-2">
                          <span class="font-medium min-w-0 flex-shrink-0"><%= format_field_name(field) %>:</span>
                          <span class="break-all">
                            <%= if log.metadata["before"] && log.metadata["before"][field] do %>
                              <span class="text-red-600 line-through">
                                <%= format_field_value(log.metadata["before"][field]) %>
                              </span>
                              <span class="mx-1">→</span>
                            <% end %>
                            <span class="text-green-600 font-medium">
                              <%= format_field_value(new_value) %>
                            </span>
                          </span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                  
                  <div class="flex items-center gap-4 text-xs text-base-content/50">
                    <span>
                      <%= Calendar.strftime(log.inserted_at, "%b %d, %Y at %I:%M %p") %>
                    </span>
                    <span class="flex items-center gap-1">
                      <span class="text-base-content/60">by</span>
                      <span class="font-medium text-base-content/80">
                        <%= log.admin_user.username || log.admin_user.email %>
                      </span>
                      <span class="text-base-content/50">(<%= log.admin_user.email %>)</span>
                    </span>
                  </div>
                </div>
                
                <div class="text-right">
                  <span class="badge badge-sm badge-outline">
                    <%= String.capitalize(log.action) %>
                  </span>
                </div>
              </div>
            </div>
          <% end %>
          <%= if Enum.empty?(@recent_admin_logs) do %>
            <p class="text-base-content/50 text-center py-4">No admin actions logged yet</p>
          <% end %>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="bg-base-100 rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-bold mb-4">Quick Actions</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.action_button 
            href={~p"/admin/email-subscriptions"} 
            icon="📧" 
            title="Email Subscriptions" 
            description="Manage landing page signups" />
          
          <.action_button 
            href={~p"/admin/users"} 
            icon="👥" 
            title="User Management" 
            description="View and manage user accounts" />
          
          <.action_button 
            href={~p"/admin/stores"} 
            icon="🏪" 
            title="Store Management" 
            description="Monitor and manage stores" />
          
          <.action_button 
            href={~p"/admin/products"} 
            icon="📦" 
            title="Product Management" 
            description="Review and manage products" />
          
          <.action_button 
            href={~p"/admin/kyc-verification"} 
            icon="🆔" 
            title="KYC Verification" 
            description="Review and verify store KYC submissions" />
          
          <.action_button 
            href={~p"/admin/support"} 
            icon="🎫" 
            title="Support Dashboard" 
            description="Manage support tickets and customer issues" />
        </div>
      </div>

      <!-- System Health -->
      <div class="bg-base-100 rounded-lg shadow p-6 mt-8">
        <h2 class="text-xl font-bold mb-4">System Health</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <.health_card 
            title="Database" 
            status="healthy" 
            icon="🗄️" 
            description="All systems operational" />
          
          <.health_card 
            title="Email Service" 
            status="healthy" 
            icon="📧" 
            description="Subscriptions working" />
          
          <.health_card 
            title="Payment Processing" 
            status="healthy" 
            icon="💳" 
            description="Stripe integration active" />
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="stat bg-base-100 shadow rounded-lg">
      <div class="stat-figure text-2xl"><%= @icon %></div>
      <div class="stat-title"><%= @title %></div>
      <div class={["stat-value", "text-#{@color}"]}><%= @value %></div>
      <%= if Map.has_key?(assigns, :link) do %>
        <div class="stat-actions">
          <a href={@link} class="btn btn-sm btn-outline">View Details</a>
        </div>
      <% end %>
    </div>
    """
  end

  defp action_button(assigns) do
    ~H"""
    <a href={@href} class="block p-4 border border-base-300 rounded-lg hover:border-primary transition-colors">
      <div class="text-3xl mb-2"><%= @icon %></div>
      <h3 class="font-semibold mb-1"><%= @title %></h3>
      <p class="text-sm text-base-content/70"><%= @description %></p>
    </a>
    """
  end

  defp health_card(assigns) do
    ~H"""
    <div class="p-4 border border-base-300 rounded-lg">
      <div class="flex items-center gap-3 mb-2">
        <span class="text-2xl"><%= @icon %></span>
        <span class="font-semibold"><%= @title %></span>
        <span class={[
          "badge badge-xs",
          if(@status == "healthy", do: "badge-success", else: "badge-error")
        ]}>
          <%= @status %>
        </span>
      </div>
      <p class="text-sm text-base-content/70"><%= @description %></p>
    </div>
    """
  end

  # Helper function to format field names for display
  defp format_field_name(field) do
    case field do
      "title" -> "Product Title"
      "description" -> "Description"
      "price" -> "Price"
      "type" -> "Product Type"
      "category_id" -> "Platform Category"
      "custom_category_id" -> "Store Category"
      "slug" -> "Product Slug"
      "file_path" -> "Digital File Path"
      "name" -> "Name"
      "email" -> "Email"
      "username" -> "Username"
      "role" -> "Role"
      "status" -> "Status"
      _ -> String.replace(field, "_", " ") |> String.capitalize()
    end
  end

  # Helper function to format field values for display
  defp format_field_value(value) do
    cond do
      is_nil(value) -> "nil"
      value == "" -> "(empty)"
      is_binary(value) -> value
      true -> inspect(value)
    end
  end
end
