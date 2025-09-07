defmodule ShompWeb.NotificationHook do
  @moduledoc """
  Hook for managing notification state across LiveViews.
  """
  import Phoenix.LiveView, only: [on_mount: 1, connected?: 1]
  
  # Helper function to safely assign values
  defp safe_assign(socket, key, value) do
    Map.put(socket, :assigns, Map.put(socket.assigns, key, value))
  end

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) and socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
      
      socket = 
        socket
        |> safe_assign(:unread_count, unread_count)
        |> safe_assign(:recent_notifications, recent_notifications)
        |> safe_assign(:show_notifications, false)
      
      {:cont, socket}
    else
      # Set default values for unauthenticated users
      socket = 
        socket
        |> safe_assign(:unread_count, 0)
        |> safe_assign(:recent_notifications, [])
        |> safe_assign(:show_notifications, false)
      
      {:cont, socket}
    end
  end

  def on_mount(:require_authenticated, _params, _session, socket) do
    if connected?(socket) and socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
      
      socket = 
        socket
        |> safe_assign(:unread_count, unread_count)
        |> safe_assign(:recent_notifications, recent_notifications)
        |> safe_assign(:show_notifications, false)
      
      {:cont, socket}
    else
      # Set default values for unauthenticated users
      socket = 
        socket
        |> safe_assign(:unread_count, 0)
        |> safe_assign(:recent_notifications, [])
        |> safe_assign(:show_notifications, false)
      
      {:cont, socket}
    end
  end
end
