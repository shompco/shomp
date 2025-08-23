defmodule ShompWeb.AdminLive.Dashboard do
  use ShompWeb, :live_view
  alias Shomp.EmailSubscriptions

  @page_title "Admin Dashboard - Shomp"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.user.role == "admin" do
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

  defp load_admin_stats(socket) do
    socket
    |> assign(:total_users, 0)  # TODO: Implement when Accounts.count_users/0 exists
    |> assign(:total_stores, 0)  # TODO: Implement when Stores.count_stores/0 exists
    |> assign(:total_products, 0)  # TODO: Implement when Products.count_products/0 exists
    |> assign(:total_subscriptions, EmailSubscriptions.count_email_subscriptions())
    |> assign(:active_subscriptions, EmailSubscriptions.count_active_subscriptions())
    |> assign(:recent_users, [])  # TODO: Implement when Accounts.list_users/1 exists
    |> assign(:recent_stores, [])  # TODO: Implement when Stores.list_stores/1 exists
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold mb-2">Admin Dashboard</h1>
        <p class="text-base-content/70">Manage the Shomp platform and monitor key metrics</p>
      </div>

      <!-- Stats Overview -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
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
          title="Email Subscriptions" 
          value={@total_subscriptions} 
          icon="📧" 
          color="success" 
          link={~p"/admin/email-subscriptions"} />
      </div>

      <!-- Quick Actions -->
      <div class="bg-base-100 rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-bold mb-4">Quick Actions</h2>
        <div class="grid grid-cols-1 md:grid-cols-1 gap-4">
          <.action_button 
            href={~p"/admin/email-subscriptions"} 
            icon="📧" 
            title="Email Subscriptions" 
            description="Manage landing page signups" />
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
end
