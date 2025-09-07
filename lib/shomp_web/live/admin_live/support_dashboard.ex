defmodule ShompWeb.AdminLive.SupportDashboard do
  use ShompWeb, :live_view

  alias Shomp.SupportTickets
  alias Shomp.Accounts

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(_params, _session, socket) do
    # Get dashboard statistics
    stats = get_dashboard_stats()
    
    # Get recent tickets
    recent_tickets = SupportTickets.list_admin_tickets(%{status: "open"}) |> Enum.take(10)
    
    # Get urgent tickets
    urgent_tickets = SupportTickets.list_admin_tickets(%{priority: "urgent"}) |> Enum.take(5)
    
    # Get all tickets for filtering
    all_tickets = SupportTickets.list_admin_tickets()
    
    socket = 
      socket
      |> assign(:stats, stats)
      |> assign(:recent_tickets, recent_tickets)
      |> assign(:urgent_tickets, urgent_tickets)
      |> assign(:all_tickets, all_tickets)
      |> assign(:filtered_tickets, all_tickets)
      |> assign(:filters, %{status: "", priority: "", category: ""})
      |> assign(:page_title, "Support Dashboard")

    {:ok, socket}
  end

  def handle_event("assign_ticket", %{"ticket_id" => ticket_id}, socket) do
    ticket = SupportTickets.get_ticket!(ticket_id)
    admin_user = socket.assigns.current_scope.user
    
    case SupportTickets.assign_ticket(ticket, admin_user.id) do
      {:ok, updated_ticket} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Ticket assigned to you")
         |> assign(:recent_tickets, update_ticket_in_list(socket.assigns.recent_tickets, updated_ticket))
         |> assign(:filtered_tickets, update_ticket_in_list(socket.assigns.filtered_tickets, updated_ticket))}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to assign ticket")}
    end
  end

  def handle_event("resolve_ticket", %{"ticket_id" => ticket_id, "resolution_notes" => notes}, socket) do
    ticket = SupportTickets.get_ticket!(ticket_id)
    admin_user = socket.assigns.current_scope.user
    
    case SupportTickets.resolve_ticket(ticket, admin_user.id, notes) do
      {:ok, updated_ticket} ->
        # Send resolution notification to customer
        # Shomp.Notifications.send_ticket_resolution_notification(updated_ticket)
        
        {:noreply, 
         socket
         |> put_flash(:info, "Ticket resolved successfully")
         |> assign(:recent_tickets, update_ticket_in_list(socket.assigns.recent_tickets, updated_ticket))
         |> assign(:filtered_tickets, update_ticket_in_list(socket.assigns.filtered_tickets, updated_ticket))}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to resolve ticket")}
    end
  end

  def handle_event("filter_tickets", %{"filters" => filters}, socket) do
    filtered_tickets = SupportTickets.list_admin_tickets(filters)
    
    {:noreply, 
     socket
     |> assign(:filtered_tickets, filtered_tickets)
     |> assign(:filters, filters)}
  end

  defp get_dashboard_stats do
    %{
      total_tickets: SupportTickets.count_tickets(),
      open_tickets: SupportTickets.count_tickets(%{status: "open"}),
      urgent_tickets: SupportTickets.count_tickets(%{priority: "urgent"}),
      resolved_today: SupportTickets.count_tickets_resolved_today(),
      avg_resolution_time: SupportTickets.avg_resolution_time_hours()
    }
  end

  defp update_ticket_in_list(tickets, updated_ticket) do
    Enum.map(tickets, fn ticket ->
      if ticket.ticket_number == updated_ticket.ticket_number, do: updated_ticket, else: ticket
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">Support Dashboard</h1>
        <a href={~p"/admin"} class="btn btn-ghost">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
          </svg>
          Back to Admin
        </a>
      </div>

      <!-- Statistics Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Total Tickets</div>
          <div class="stat-value text-primary"><%= @stats.total_tickets %></div>
        </div>
        
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Open Tickets</div>
          <div class="stat-value text-warning"><%= @stats.open_tickets %></div>
        </div>
        
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Urgent</div>
          <div class="stat-value text-error"><%= @stats.urgent_tickets %></div>
        </div>
        
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Resolved Today</div>
          <div class="stat-value text-success"><%= @stats.resolved_today %></div>
        </div>
        
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Avg Resolution</div>
          <div class="stat-value text-info"><%= @stats.avg_resolution_time %>h</div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Urgent Tickets -->
        <div class="lg:col-span-1">
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-error">Urgent Tickets</h2>
              
              <div class="space-y-3">
                <%= if Enum.empty?(@urgent_tickets) do %>
                  <p class="text-gray-500 text-sm">No urgent tickets</p>
                <% else %>
                  <%= for ticket <- @urgent_tickets do %>
                    <div class="border-l-4 border-error pl-3">
                      <div class="flex justify-between items-start">
                        <div class="flex-1">
                          <h4 class="font-semibold text-sm">
                            <a href={~p"/admin/support/#{ticket.ticket_number}"} class="link link-hover">
                              <%= ticket.subject %>
                            </a>
                          </h4>
                          <p class="text-xs text-gray-500">
                            <%= ticket.ticket_number %> • <%= ticket.user.email %>
                          </p>
                        </div>
                        <button 
                          phx-click="assign_ticket" 
                          phx-value-ticket_id={ticket.ticket_number}
                          class="btn btn-xs btn-primary"
                        >
                          Assign
                        </button>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <!-- All Tickets with Filters -->
        <div class="lg:col-span-2">
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <div class="flex justify-between items-center mb-4">
                <h2 class="card-title">All Tickets</h2>
                
                <!-- Filters -->
                <div class="flex gap-2">
                  <select 
                    phx-change="filter_tickets" 
                    name="filters[status]"
                    class="select select-bordered select-sm"
                  >
                    <option value="">All Status</option>
                    <option value="open">Open</option>
                    <option value="in_progress">In Progress</option>
                    <option value="waiting_customer">Waiting Customer</option>
                    <option value="resolved">Resolved</option>
                    <option value="closed">Closed</option>
                  </select>
                  
                  <select 
                    phx-change="filter_tickets" 
                    name="filters[priority]"
                    class="select select-bordered select-sm"
                  >
                    <option value="">All Priority</option>
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                    <option value="urgent">Urgent</option>
                  </select>
                  
                  <select 
                    phx-change="filter_tickets" 
                    name="filters[category]"
                    class="select select-bordered select-sm"
                  >
                    <option value="">All Categories</option>
                    <option value="order_issue">Order Issue</option>
                    <option value="payment_issue">Payment Issue</option>
                    <option value="technical">Technical</option>
                    <option value="account">Account</option>
                    <option value="other">Other</option>
                  </select>
                </div>
              </div>
              
              <div class="overflow-x-auto">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th>Ticket</th>
                      <th>Customer</th>
                      <th>Status</th>
                      <th>Priority</th>
                      <th>Category</th>
                      <th>Assigned</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for ticket <- @filtered_tickets do %>
                      <tr>
                        <td>
                          <div>
                            <div class="font-bold">
                              <a href={~p"/admin/support/#{ticket.ticket_number}"} class="link link-hover">
                                <%= ticket.ticket_number %>
                              </a>
                            </div>
                            <div class="text-sm opacity-50">
                              <%= String.slice(ticket.subject, 0, 30) %>
                              <%= if String.length(ticket.subject) > 30, do: "..." %>
                            </div>
                          </div>
                        </td>
                        <td>
                          <div class="text-sm">
                            <%= ticket.user.email %>
                          </div>
                        </td>
                        <td>
                          <div class="badge badge-outline">
                            <%= String.capitalize(ticket.status) %>
                          </div>
                        </td>
                        <td>
                          <div class={"badge #{priority_badge_class(ticket.priority)}"}>
                            <%= String.capitalize(ticket.priority) %>
                          </div>
                        </td>
                        <td>
                          <div class="text-sm">
                            <%= String.capitalize(ticket.category) %>
                          </div>
                        </td>
                        <td>
                          <div class="text-sm">
                            <%= if ticket.assigned_to_user do %>
                              <%= ticket.assigned_to_user.username || ticket.assigned_to_user.email %>
                            <% else %>
                              <span class="text-gray-400">Unassigned</span>
                            <% end %>
                          </div>
                        </td>
                        <td>
                          <div class="flex gap-1">
                            <%= if !ticket.assigned_to_user do %>
                              <button 
                                phx-click="assign_ticket" 
                                phx-value-ticket_id={ticket.ticket_number}
                                class="btn btn-xs btn-primary"
                              >
                                Assign
                              </button>
                            <% end %>
                            <%= if ticket.status != "resolved" and ticket.status != "closed" do %>
                              <a href={~p"/admin/support/#{ticket.ticket_number}"} class="btn btn-xs btn-ghost">
                                View
                              </a>
                            <% end %>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp priority_badge_class(priority) do
    case priority do
      "urgent" -> "badge-error"
      "high" -> "badge-warning"
      "medium" -> "badge-info"
      "low" -> "badge-success"
      _ -> "badge-ghost"
    end
  end
end
