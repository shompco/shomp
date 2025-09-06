defmodule ShompWeb.SupportLive.Index do
  use ShompWeb, :live_view

  alias Shomp.SupportTickets
  alias Shomp.Orders

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    tickets = SupportTickets.list_user_tickets(user.id)
    orders = Orders.list_user_orders(user.id)
    
    # Check if order_id is provided in params to pre-select an order
    pre_selected_order_id = params["order_id"]
    show_form = pre_selected_order_id != nil
    
    # Initialize changeset with pre-selected order if provided
    initial_params = if pre_selected_order_id, do: %{"order_id" => pre_selected_order_id}, else: %{}
    initial_changeset = SupportTickets.SupportTicket.changeset(%SupportTickets.SupportTicket{}, initial_params)
    
    socket = 
      socket
      |> assign(:tickets, tickets)
      |> assign(:orders, orders)
      |> assign(:page_title, "Support Tickets")
      |> assign(:show_new_ticket_form, show_form)
      |> assign(:pre_selected_order_id, pre_selected_order_id)
      |> assign(:ticket_changeset, initial_changeset)
      |> assign(:ticket_form, to_form(initial_changeset))

    {:ok, socket}
  end

  def handle_event("show_new_ticket_form", _params, socket) do
    {:noreply, assign(socket, :show_new_ticket_form, true)}
  end

  def handle_event("hide_new_ticket_form", _params, socket) do
    {:noreply, assign(socket, :show_new_ticket_form, false)}
  end



  def handle_event("create_ticket", %{"support_ticket" => ticket_params}, socket) do
    user = socket.assigns.current_scope.user
    
    ticket_params = 
      ticket_params
      |> Map.put("user_id", user.id)
      |> Map.put("last_activity_at", DateTime.utc_now())

    case SupportTickets.create_ticket(ticket_params) do
      {:ok, ticket} ->
        # Send notification to admin
        # Shomp.Notifications.send_new_ticket_notification(ticket)
        
        new_changeset = SupportTickets.SupportTicket.changeset(%SupportTickets.SupportTicket{}, %{})
        
        {:noreply, 
         socket
         |> put_flash(:info, "Support ticket created successfully")
         |> assign(:tickets, [ticket | socket.assigns.tickets])
         |> assign(:show_new_ticket_form, false)
         |> assign(:ticket_changeset, new_changeset)
         |> assign(:ticket_form, to_form(new_changeset))}
      
      {:error, changeset} ->
        {:noreply, 
         socket
         |> assign(:ticket_changeset, changeset)
         |> assign(:ticket_form, to_form(changeset))}
    end
  end

  def handle_event("validate_ticket", %{"support_ticket" => ticket_params}, socket) do
    # Use proper LiveView form validation
    changeset = 
      %SupportTickets.SupportTicket{}
      |> SupportTickets.SupportTicket.changeset(ticket_params)
      |> Map.put(:action, :validate)
    
    {:noreply, 
     socket
     |> assign(:ticket_changeset, changeset)
     |> assign(:ticket_form, to_form(changeset))}
  end

  def handle_event("filter_tickets", %{"filters" => filters}, socket) do
    user = socket.assigns.current_scope.user
    tickets = SupportTickets.list_user_tickets(user.id, filters)
    
    {:noreply, assign(socket, :tickets, tickets)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">Support Tickets</h1>
        <button 
          type="button"
          phx-click="show_new_ticket_form" 
          class="btn btn-primary"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
          </svg>
          New Ticket
        </button>
      </div>

      <!-- New Ticket Form -->
      <%= if @show_new_ticket_form do %>
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h2 class="card-title">Create New Support Ticket</h2>
            
            <.form 
              for={@ticket_form}
              id="ticket-form"
              phx-submit="create_ticket"
              phx-change="validate_ticket"
              class="space-y-4"
            >
              <.input
                field={@ticket_form[:subject]}
                type="text"
                label="Subject"
                placeholder="Brief description of your issue"
              />

              <.input
                field={@ticket_form[:category]}
                type="select"
                label="Category"
                options={[
                  {"Select a category", ""},
                  {"Order Issue", "order_issue"},
                  {"Payment Issue", "payment_issue"},
                  {"Technical Problem", "technical"},
                  {"Account Issue", "account"},
                  {"Other", "other"}
                ]}
              />

              <.input
                field={@ticket_form[:priority]}
                type="select"
                label="Priority"
                options={[
                  {"Low", "low"},
                  {"Medium", "medium"},
                  {"High", "high"},
                  {"Urgent", "urgent"}
                ]}
              />

              <.input
                field={@ticket_form[:description]}
                type="textarea"
                label="Description"
                placeholder="Please provide detailed information about your issue..."
              />

              <.input
                field={@ticket_form[:order_id]}
                type="select"
                label="Related Order (Optional)"
                options={[
                  {"No specific order", ""} | 
                  Enum.map(@orders, fn order -> 
                    {"Order ##{order.immutable_id} - $#{order.total_amount} - #{String.capitalize(order.status)} - #{Calendar.strftime(order.inserted_at, "%b %d, %Y")}", to_string(order.id)}
                  end)
                ]}
              />

              <div class="card-actions justify-end">
                <button type="button" phx-click="hide_new_ticket_form" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">
                  Create Ticket
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Tickets List -->
      <div class="space-y-4">
        <%= if Enum.empty?(@tickets) do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No support tickets</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by creating a new support ticket.</p>
          </div>
        <% else %>
          <%= for ticket <- @tickets do %>
            <div class="card bg-base-100 shadow hover:shadow-lg transition-shadow">
              <div class="card-body">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-2">
                      <h3 class="text-lg font-semibold">
                        <a href={~p"/support/#{ticket.id}"} class="link link-hover">
                          <%= ticket.subject %>
                        </a>
                      </h3>
                      <div class="badge badge-outline">
                        <%= ticket.ticket_number %>
                      </div>
                    </div>
                    
                    <p class="text-gray-600 text-sm mb-2">
                      <%= String.slice(ticket.description, 0, 150) %>
                      <%= if String.length(ticket.description) > 150, do: "..." %>
                    </p>
                    
                    <div class="flex items-center gap-4 text-sm text-gray-500">
                      <span class="badge badge-ghost">
                        <%= String.capitalize(ticket.category) %>
                      </span>
                      <span class="badge badge-ghost">
                        <%= String.capitalize(ticket.priority) %>
                      </span>
                      <span class="badge badge-ghost">
                        <%= String.capitalize(ticket.status) %>
                      </span>
                      <%= if ticket.order do %>
                        <span class="badge badge-primary">
                          Order #<%= ticket.order.immutable_id %>
                        </span>
                      <% end %>
                      <span>
                        <%= if ticket.last_activity_at do %>
                          <%= Calendar.strftime(ticket.last_activity_at, "%b %d, %Y at %I:%M %p") %>
                        <% else %>
                          <%= Calendar.strftime(ticket.inserted_at, "%b %d, %Y at %I:%M %p") %>
                        <% end %>
                      </span>
                    </div>
                  </div>
                  
                  <div class="flex flex-col items-end gap-2">
                    <a href={~p"/support/#{ticket.id}"} class="btn btn-sm btn-primary">
                      View Details
                    </a>
                    <%= if ticket.assigned_to_user do %>
                      <span class="text-xs text-gray-500">
                        Assigned to: <%= ticket.assigned_to_user.username || ticket.assigned_to_user.email %>
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
