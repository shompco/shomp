defmodule ShompWeb.NotificationLive do
  @moduledoc """
  Global notification LiveView for handling notification events.
  """
  use ShompWeb, :live_view
  import Phoenix.LiveView, only: [connected?: 1, on_mount: 1]

  on_mount {ShompWeb.UserAuth, :mount_current_scope}
  
  # Helper function to safely assign values
  defp safe_assign(socket, key, value) do
    Map.put(socket, :assigns, Map.put(socket.assigns, key, value))
  end

  def mount(_params, _session, socket) do
    if connected?(socket) and socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
      
      socket = 
        socket
        |> safe_assign(:unread_count, unread_count)
        |> safe_assign(:recent_notifications, recent_notifications)
        |> safe_assign(:show_notifications, false)
      
      {:ok, socket}
    else
      {:ok, 
       socket
        |> safe_assign(:unread_count, 0)
        |> safe_assign(:recent_notifications, [])
        |> safe_assign(:show_notifications, false)}
    end
  end

  def handle_event("toggle_notifications", _params, socket) do
    show_notifications = !socket.assigns[:show_notifications]
    {:noreply, safe_assign(socket, :show_notifications, show_notifications)}
  end

  def handle_event("mark_notification_read", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    notification = Shomp.Notifications.get_notification!(id)
    
    if notification.user_id == user.id do
      case Shomp.Notifications.mark_as_read(notification) do
        {:ok, _notification} ->
          # Refresh notifications and unread count
          unread_count = Shomp.Notifications.unread_count(user.id)
          recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
          
          {:noreply, 
           socket
            |> safe_assign(:unread_count, unread_count)
            |> safe_assign(:recent_notifications, recent_notifications)}
        
        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_scope.user
    
    case Shomp.Notifications.mark_all_as_read(user.id) do
      {_count, _} ->
        # Refresh notifications and unread count
        unread_count = Shomp.Notifications.unread_count(user.id)
        recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
        
        {:noreply, 
         socket
         |> assign(:unread_count, unread_count)
         |> assign(:recent_notifications, recent_notifications)}
      
      _ ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div></div>
    """
  end
end
