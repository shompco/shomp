defmodule ShompWeb.NotificationHook do
  @moduledoc """
  Hook for managing notification state across LiveViews with real-time updates via PubSub.
  """
  import Phoenix.LiveView, only: [connected?: 1, push_event: 3]
  alias Phoenix.PubSub

  # Helper function to safely assign values
  defp safe_assign(socket, key, value) do
    Map.put(socket, :assigns, Map.put(socket.assigns, key, value))
  end

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) and socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      
      # Subscribe to user-specific notification channel
      PubSub.subscribe(Shomp.PubSub, "notifications:#{user.id}")
      
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)

      socket =
        socket
        |> safe_assign(:unread_count, unread_count)
        |> safe_assign(:recent_notifications, recent_notifications)
        |> safe_assign(:show_notifications, false)
        |> push_event("notification-count-updated", %{count: unread_count})

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
      
      # Subscribe to user-specific notification channel
      PubSub.subscribe(Shomp.PubSub, "notifications:#{user.id}")
      
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)

      socket =
        socket
        |> safe_assign(:unread_count, unread_count)
        |> safe_assign(:recent_notifications, recent_notifications)
        |> safe_assign(:show_notifications, false)
        |> push_event("notification-count-updated", %{count: unread_count})

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

  # Handle real-time notification updates
  def handle_info({:notification_created, _notification}, socket) do
    if socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
      
      {:noreply, 
       socket
       |> safe_assign(:unread_count, unread_count)
       |> safe_assign(:recent_notifications, recent_notifications)
       |> push_event("notification-count-updated", %{count: unread_count})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:notification_read, _notification_id}, socket) do
    if socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
      
      {:noreply, 
       socket
       |> safe_assign(:unread_count, unread_count)
       |> safe_assign(:recent_notifications, recent_notifications)
       |> push_event("notification-count-updated", %{count: unread_count})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:notifications_updated}, socket) do
    if socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      unread_count = Shomp.Notifications.unread_count(user.id)
      recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)
      
      {:noreply, 
       socket
       |> safe_assign(:unread_count, unread_count)
       |> safe_assign(:recent_notifications, recent_notifications)
       |> push_event("notification-count-updated", %{count: unread_count})}
    else
      {:noreply, socket}
    end
  end

  # Handle notification events from the UI
  def handle_event("toggle_notifications", _params, socket) do
    show_notifications = !socket.assigns[:show_notifications]
    {:noreply, safe_assign(socket, :show_notifications, show_notifications)}
  end

  def handle_event("mark_notification_read", %{"id" => id}, socket) do
    if socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      notification = Shomp.Notifications.get_notification!(id)
      
      if notification.user_id == user.id do
        case Shomp.Notifications.mark_as_read(notification) do
          {:ok, _notification} ->
            # Broadcast the update to all connected sessions
            PubSub.broadcast(Shomp.PubSub, "notifications:#{user.id}", {:notification_read, id})
            {:noreply, socket}
          
          {:error, _changeset} ->
            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    if socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      
      case Shomp.Notifications.mark_all_as_read(user.id) do
        {_count, _} ->
          # Broadcast the update to all connected sessions
          PubSub.broadcast(Shomp.PubSub, "notifications:#{user.id}", {:notifications_updated})
          {:noreply, socket}
        
        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end
end
