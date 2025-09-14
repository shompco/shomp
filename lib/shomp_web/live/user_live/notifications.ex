defmodule ShompWeb.UserLive.Notifications do
  use ShompWeb, :live_view

  alias Shomp.Notifications

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    notifications = Notifications.list_user_notifications(user.id)
    unread_count = Notifications.unread_count(user.id)

    {:ok,
     socket
     |> assign(:page_title, "Notifications")
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_event("mark_as_read", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    notification = Notifications.get_notification!(id)

    if notification.user_id == user.id do
      case Notifications.mark_as_read(notification) do
        {:ok, _notification} ->
          # Refresh notifications and unread count
          notifications = Notifications.list_user_notifications(user.id)
          unread_count = Notifications.unread_count(user.id)

          {:noreply,
           socket
           |> assign(:notifications, notifications)
           |> assign(:unread_count, unread_count)
           |> put_flash(:info, "Notification marked as read")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to mark notification as read")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_scope.user

    case Notifications.mark_all_as_read(user.id) do
      {count, _} ->
        # Refresh notifications and unread count
        notifications = Notifications.list_user_notifications(user.id)
        unread_count = Notifications.unread_count(user.id)

        {:noreply,
         socket
         |> assign(:notifications, notifications)
         |> assign(:unread_count, unread_count)
         |> put_flash(:info, "Marked #{count} notifications as read")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to mark notifications as read")}
    end
  end

  @impl true
  def handle_event("navigate_to_notification", %{"url" => url}, socket) do
    {:noreply, push_navigate(socket, to: url)}
  end

  @impl true
  def handle_event("hide_notification", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    notification = Notifications.get_notification!(id)

    if notification.user_id == user.id do
      case Notifications.delete_notification(notification) do
        {:ok, _notification} ->
          # Refresh notifications and unread count
          notifications = Notifications.list_user_notifications(user.id)
          unread_count = Notifications.unread_count(user.id)

          {:noreply,
           socket
           |> assign(:notifications, notifications)
           |> assign(:unread_count, unread_count)
           |> put_flash(:info, "Notification hidden")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to hide notification")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Notifications
        <:actions>
          <%= if @unread_count > 0 do %>
            <button
              phx-click="mark_all_read"
              class="btn btn-primary btn-sm"
            >
              Mark All Read
            </button>
          <% end %>
        </:actions>
      </.header>

      <div class="space-y-4">
        <%= if @notifications == [] do %>
          <div class="text-center py-12">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
            </svg>
            <h3 class="text-lg font-medium text-gray-700 mb-2">No notifications yet</h3>
            <p class="text-sm text-gray-500">We'll notify you about order updates, support tickets, and other important updates here.</p>
          </div>
        <% else %>
          <%= for notification <- @notifications do %>
            <div
              class={"bg-white rounded-lg shadow-sm border p-4 cursor-pointer hover:shadow-md transition-shadow #{if notification.read, do: "opacity-75", else: "border-l-4 border-l-blue-500"}"}
              phx-click={if notification.action_url, do: "navigate_to_notification", else: nil}
              phx-value-url={notification.action_url}
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-2 mb-2">
                    <h3 class="font-medium text-gray-900">{notification.title}</h3>
                    <%= if not notification.read do %>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        New
                      </span>
                    <% end %>
                  </div>

                  <p class="text-gray-600 mb-2">{notification.message}</p>

                  <div class="flex items-center justify-between text-sm text-gray-500">
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      <%= String.capitalize(notification.type) %>
                    </span>
                    <span><%= Calendar.strftime(notification.inserted_at, "%b %d, %Y at %I:%M %p") %></span>
                  </div>
                </div>

                <div class="flex items-center space-x-2 ml-4">
                  <%= if not notification.read do %>
                    <button
                      phx-click="mark_as_read"
                      phx-value-id={notification.id}
                      class="btn btn-ghost btn-xs"
                      phx-click-away
                    >
                      Mark Read
                    </button>
                  <% end %>
                  <button
                    phx-click="hide_notification"
                    phx-value-id={notification.id}
                    class="btn btn-ghost btn-xs text-gray-400 hover:text-gray-600"
                    phx-click-away
                    title="Hide notification"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
