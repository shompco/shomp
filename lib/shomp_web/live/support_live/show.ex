defmodule ShompWeb.SupportLive.Show do
  use ShompWeb, :live_view

  alias Shomp.SupportTickets

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(%{"ticket_number" => ticket_number}, _session, socket) do
    ticket = SupportTickets.get_ticket_by_ticket_number!(ticket_number)
    user = socket.assigns.current_scope.user
    
    # Verify user owns this ticket or is admin
    if ticket.user_id != user.id and !is_admin?(user) do
      raise Phoenix.Router.NoRouteError, "Not Found"
    end
    
    socket = 
      socket
      |> assign(:ticket, ticket)
      |> assign(:page_title, "Ticket #{ticket.ticket_number}")
      |> assign(:message_changeset, SupportTickets.SupportMessage.changeset(%SupportTickets.SupportMessage{}, %{}))

    {:ok, socket}
  end

  def handle_event("validate_message", %{"support_message" => message_params}, socket) do
    changeset = 
      %SupportTickets.SupportMessage{}
      |> SupportTickets.SupportMessage.changeset(message_params)
      |> Map.put(:action, :validate)
    
    {:noreply, assign(socket, :message_changeset, changeset)}
  end

  def handle_event("add_message", %{"support_message" => message_params}, socket) do
    ticket = socket.assigns.ticket
    user = socket.assigns.current_scope.user
    
    message_params = 
      message_params
      |> Map.put("author_user_id", user.id)
      |> Map.put("is_from_admin", is_admin?(user))

    case SupportTickets.add_message(ticket, message_params) do
      {:ok, _message} ->
        # Send notification to other party
        # if is_admin?(user) do
        #   Shomp.Notifications.send_ticket_reply_notification(ticket, message)
        # else
        #   Shomp.Notifications.send_admin_ticket_reply_notification(ticket, message)
        # end
        
        {:noreply, 
         socket
         |> put_flash(:info, "Message sent successfully")
         |> assign(:ticket, SupportTickets.get_ticket!(ticket.id))
         |> assign(:message_changeset, SupportTickets.SupportMessage.changeset(%SupportTickets.SupportMessage{}, %{}))}
      
      {:error, changeset} ->
        {:noreply, assign(socket, :message_changeset, changeset)}
    end
  end

  def handle_event("resolve_ticket", %{"resolution_notes" => notes}, socket) do
    ticket = socket.assigns.ticket
    user = socket.assigns.current_scope.user
    
    if is_admin?(user) do
      case SupportTickets.resolve_ticket(ticket, user.id, notes) do
        {:ok, updated_ticket} ->
          # Send resolution notification to customer
          # Shomp.Notifications.send_ticket_resolution_notification(updated_ticket)
          
          {:noreply, 
           socket
           |> put_flash(:info, "Ticket resolved successfully")
           |> assign(:ticket, updated_ticket)}
        
        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to resolve ticket")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only administrators can resolve tickets")}
    end
  end

  defp is_admin?(user) do
    user.role == "admin"
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-3xl font-bold">Support Ticket</h1>
          <p class="text-gray-600">#{@ticket.ticket_number}</p>
        </div>
        <a href={~p"/support"} class="btn btn-ghost">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
          </svg>
          Back to Tickets
        </a>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Ticket Details -->
        <div class="lg:col-span-2 space-y-6">
          <!-- Ticket Info -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <div class="flex justify-between items-start mb-4">
                <h2 class="text-xl font-semibold"><%= @ticket.subject %></h2>
                <div class="flex gap-2">
                  <div class="badge badge-outline">
                    <%= String.capitalize(@ticket.status) %>
                  </div>
                  <div class="badge badge-outline">
                    <%= String.capitalize(@ticket.priority) %>
                  </div>
                </div>
              </div>
              
              <p class="text-gray-700 mb-4"><%= @ticket.description %></p>
              
              <div class="text-sm text-gray-500">
                <p><strong>Category:</strong> <%= String.capitalize(@ticket.category) %></p>
                <p><strong>Created:</strong> <%= Calendar.strftime(@ticket.inserted_at, "%b %d, %Y at %I:%M %p") %></p>
                <p><strong>Last Activity:</strong> <%= Calendar.strftime(@ticket.last_activity_at, "%b %d, %Y at %I:%M %p") %></p>
                <%= if @ticket.assigned_to_user do %>
                  <p><strong>Assigned to:</strong> <%= @ticket.assigned_to_user.username || @ticket.assigned_to_user.email %></p>
                <% end %>
                <%= if @ticket.resolved_at do %>
                  <p><strong>Resolved:</strong> <%= Calendar.strftime(@ticket.resolved_at, "%b %d, %Y at %I:%M %p") %></p>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Related Order Information -->
          <%= if @ticket.order do %>
            <div class="card bg-base-100 shadow">
              <div class="card-body">
                <h3 class="text-lg font-semibold mb-4">Related Order</h3>
                <div class="flex items-center justify-between">
                  <div>
                    <p class="font-medium">Order #<%= @ticket.order.immutable_id %></p>
                    <p class="text-sm text-gray-600">
                      Total: $<%= @ticket.order.total_amount %> • 
                      Status: <%= String.capitalize(@ticket.order.status) %> • 
                      Date: <%= Calendar.strftime(@ticket.order.inserted_at, "%b %d, %Y") %>
                    </p>
                  </div>
                  <a href={~p"/orders/#{@ticket.order.immutable_id}"} class="btn btn-sm btn-outline">
                    View Order
                  </a>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Messages -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h3 class="text-lg font-semibold mb-4">Conversation</h3>
              
              <div class="space-y-4 max-h-96 overflow-y-auto">
                <%= for message <- @ticket.messages do %>
                  <div class={"flex #{if message.is_from_admin, do: "justify-end", else: "justify-start"}"}>
                    <div class={"max-w-xs lg:max-w-md px-4 py-2 rounded-lg #{if message.is_from_admin, do: "bg-primary text-primary-content", else: "bg-gray-100"}"}>
                      <p class="text-sm"><%= message.message %></p>
                      <p class="text-xs opacity-70 mt-1">
                        <%= Calendar.strftime(message.inserted_at, "%b %d at %I:%M %p") %>
                        <%= if message.is_from_admin, do: " (Admin)", else: "" %>
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Add Message Form -->
          <%= if @ticket.status != "resolved" and @ticket.status != "closed" do %>
            <div class="card bg-base-100 shadow">
              <div class="card-body">
                <h3 class="text-lg font-semibold mb-4">Add Message</h3>
                
                <form 
                  phx-submit="add_message"
                  phx-change="validate_message"
                  class="space-y-4"
                >
                  <div class="form-control">
                    <textarea 
                      name="support_message[message]"
                      value={Ecto.Changeset.get_field(@message_changeset, :message, "")}
                      class="textarea textarea-bordered w-full h-24"
                      placeholder="Type your message here..."
                      required
                    ></textarea>
                    <%= if @message_changeset.errors[:message] do %>
                      <div class="text-orange-500 text-sm">
                        <%= elem(@message_changeset.errors[:message], 0) %>
                      </div>
                    <% end %>
                  </div>
                  
                  <button type="submit" class="btn btn-primary">
                    Send Message
                  </button>
                </form>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Resolution Form (Admin Only) -->
          <%= if is_admin?(@current_scope.user) and @ticket.status != "resolved" and @ticket.status != "closed" do %>
            <div class="card bg-base-100 shadow">
              <div class="card-body">
                <h3 class="text-lg font-semibold mb-4">Admin Actions</h3>
                
                <form 
                  phx-submit="resolve_ticket"
                  class="space-y-4"
                >
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Resolution Notes</span>
                    </label>
                    <textarea 
                      name="resolution_notes"
                      class="textarea textarea-bordered w-full h-20"
                      placeholder="How was this issue resolved?"
                      required
                    ></textarea>
                  </div>
                  
                  <button type="submit" class="btn btn-success w-full">
                    Resolve Ticket
                  </button>
                </form>
              </div>
            </div>
          <% end %>

          <!-- Resolution Info -->
          <%= if @ticket.status == "resolved" or @ticket.status == "closed" do %>
            <div class="card bg-success text-success-content shadow">
              <div class="card-body">
                <h3 class="text-lg font-semibold">Ticket Resolved</h3>
                <%= if @ticket.resolution_notes do %>
                  <p class="text-sm mt-2"><%= @ticket.resolution_notes %></p>
                <% end %>
                <p class="text-xs mt-2">
                  Resolved by: <%= @ticket.resolved_by_user.username || @ticket.resolved_by_user.email %>
                </p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
