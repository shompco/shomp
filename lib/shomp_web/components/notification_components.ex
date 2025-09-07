defmodule ShompWeb.NotificationComponents do
  @moduledoc """
  Notification-related components.
  """
  use ShompWeb, :html

  @doc """
  Renders a notification bell with unread count badge.
  """
  attr :unread_count, :integer, default: 0
  attr :class, :string, default: ""

  def notification_bell(assigns) do
    ~H"""
    <div class={"relative #{@class}"}>
      <button 
        phx-click="toggle_notifications"
        class="btn btn-ghost btn-sm flex items-center space-x-1"
        id="notification-bell"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
        </svg>
        <%= if @unread_count > 0 do %>
          <span class="badge badge-error badge-sm absolute -top-1 -right-1 min-w-[1.25rem] h-5 flex items-center justify-center text-xs">
            <%= if @unread_count > 99, do: "99+", else: @unread_count %>
          </span>
        <% end %>
      </button>
    </div>
    """
  end

  @doc """
  Renders a notification dropdown with recent notifications.
  """
  attr :notifications, :list, default: []
  attr :show, :boolean, default: false

  def notification_dropdown(assigns) do
    ~H"""
    <div class={"dropdown dropdown-end #{if @show, do: "dropdown-open", else: ""}"}>
      <div tabindex="0" class="mt-3 z-[1] card card-compact w-80 bg-base-100 shadow-xl">
        <div class="card-body">
          <div class="flex items-center justify-between mb-4">
            <h3 class="card-title text-lg">Notifications</h3>
            <button 
              phx-click="mark_all_read"
              class="btn btn-ghost btn-xs"
              disabled={@notifications == []}
            >
              Mark all read
            </button>
          </div>
          
          <div class="max-h-96 overflow-y-auto">
            <%= if @notifications == [] do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-2 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
                </svg>
                <p>No notifications</p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for notification <- @notifications do %>
                  <div class={"p-3 rounded-lg border-l-4 #{if notification.read, do: "bg-gray-50 border-gray-200", else: "bg-blue-50 border-blue-400"}"}>
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <h4 class="font-medium text-sm">{notification.title}</h4>
                        <p class="text-xs text-gray-600 mt-1">{notification.message}</p>
                        <p class="text-xs text-gray-400 mt-1">
                          <%= Calendar.strftime(notification.inserted_at, "%b %d, %Y at %I:%M %p") %>
                        </p>
                      </div>
                      <%= if not notification.read do %>
                        <div class="w-2 h-2 bg-blue-500 rounded-full ml-2 mt-1"></div>
                      <% end %>
                    </div>
                    <%= if notification.action_url do %>
                      <div class="mt-2">
                        <a 
                          href={notification.action_url}
                          class="btn btn-ghost btn-xs"
                          phx-click="mark_notification_read"
                          phx-value-id={notification.id}
                        >
                          View Details
                        </a>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          
          <div class="card-actions justify-end mt-4">
            <a href="/notifications" class="btn btn-primary btn-sm">
              View All Notifications
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
