defmodule ShompWeb.AdminLive.DeleteSuccess do
  use ShompWeb, :live_view
  alias Shomp.AdminLogs

  @page_title "Delete Success - Admin Dashboard"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(params, _session, socket) do
    if socket.assigns.current_scope &&
       socket.assigns.current_scope.user.email == @admin_email do

      # Extract the deleted entity information from params
      entity_type = params["entity_type"] || "item"
      entity_name = params["entity_name"] || "Item"
      entity_id = params["entity_id"]

      # Get the admin log for this deletion
      admin_log = if entity_id do
        AdminLogs.get_admin_logs_for_entity(entity_type, String.to_integer(entity_id), 1)
        |> Enum.find(fn log -> log.action == "delete" end)
      else
        nil
      end

      {:ok,
       socket
       |> assign(:page_title, @page_title)
       |> assign(:entity_type, entity_type)
       |> assign(:entity_name, entity_name)
       |> assign(:entity_id, entity_id)
       |> assign(:admin_log, admin_log)
       |> assign(:deletion_time, DateTime.utc_now())}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="max-w-2xl mx-auto">
        <!-- Success Header -->
        <div class="text-center mb-8">
          <div class="w-20 h-20 bg-success/20 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-10 h-10 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h1 class="text-3xl font-bold text-success mb-2">Successfully Deleted!</h1>
          <p class="text-base-content/70 text-lg">
            The <%= @entity_type %> has been permanently removed from the system.
          </p>
        </div>

        <!-- Deletion Details -->
        <div class="bg-base-100 rounded-lg shadow-lg p-6 mb-8">
          <h2 class="text-xl font-semibold mb-4">Deletion Details</h2>
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-base-content/70">Item Type:</span>
              <span class="font-medium capitalize"><%= @entity_type %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/70">Item Name:</span>
              <span class="font-medium"><%= @entity_name %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/70">Deleted At:</span>
              <span class="font-medium">
                <%= Calendar.strftime(@deletion_time, "%B %d, %Y at %I:%M %p UTC") %>
              </span>
            </div>
            <%= if @entity_id do %>
              <div class="flex justify-between">
                <span class="text-base-content/70">Item ID:</span>
                <span class="font-mono text-sm"><%= @entity_id %></span>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Admin Log Details -->
        <%= if @admin_log do %>
          <div class="bg-base-100 rounded-lg shadow-lg p-6 mb-8">
            <h2 class="text-xl font-semibold mb-4">Admin Log Entry</h2>
            <div class="space-y-3">
              <div class="flex justify-between">
                <span class="text-base-content/70">Action:</span>
                <span class="font-medium capitalize"><%= @admin_log.action %></span>
              </div>
              <div class="flex justify-between">
                <span class="text-base-content/70">Logged At:</span>
                <span class="font-medium">
                  <%= Calendar.strftime(@admin_log.inserted_at, "%B %d, %Y at %I:%M %p UTC") %>
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-base-content/70">Details:</span>
                <span class="font-medium"><%= @admin_log.details %></span>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Important Notice -->
        <div class="alert alert-warning mb-8">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
          <div>
            <h3 class="font-bold">Important Notice</h3>
            <div class="text-sm">
              <p>• This action cannot be undone</p>
              <p>• All associated data has been permanently removed</p>
              <p>• The deletion has been logged for audit purposes</p>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <a href={~p"/admin/products"} class="btn btn-primary btn-lg">
            ← Back to Products
          </a>
          <a href={~p"/admin"} class="btn btn-outline btn-lg">
            ← Admin Dashboard
          </a>
        </div>
      </div>
    </div>
    """
  end
end
