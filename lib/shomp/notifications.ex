defmodule Shomp.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Notifications.Notification

  @doc """
  Returns the list of notifications for a user.
  """
  def list_user_notifications(user_id, opts \\ []) do
    limit = opts[:limit] || 50
    unread_only = opts[:unread_only] || false

    query = from n in Notification,
            where: n.user_id == ^user_id,
            order_by: [desc: n.inserted_at]

    query = if unread_only do
      from n in query, where: n.read == false
    else
      query
    end

    query = from n in query, limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets a single notification.
  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Creates a notification.
  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification.
  """
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notification.
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(%Notification{} = notification) do
    update_notification(notification, %{read: true})
  end

  @doc """
  Marks all notifications as read for a user.
  """
  def mark_all_as_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and n.read == false)
    |> Repo.update_all(set: [read: true])
  end

  @doc """
  Gets the count of unread notifications for a user.
  """
  def unread_count(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and n.read == false)
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a notification for order status updates.
  """
  def create_order_notification(user_id, order_id, status, message) do
    create_notification(%{
      user_id: user_id,
      title: "Order Update",
      message: message,
      type: "order_update",
      action_url: "/orders/#{order_id}",
      metadata: %{order_id: order_id, status: status}
    })
  end

  @doc """
  Creates a notification for support ticket updates.
  """
  def create_support_notification(user_id, ticket_id, status, message) do
    create_notification(%{
      user_id: user_id,
      title: "Support Ticket Update",
      message: message,
      type: "support_ticket",
      action_url: "/support/#{ticket_id}",
      metadata: %{ticket_id: ticket_id, status: status}
    })
  end

  @doc """
  Creates a system notification.
  """
  def create_system_notification(user_id, title, message, opts \\ []) do
    create_notification(%{
      user_id: user_id,
      title: title,
      message: message,
      type: "system",
      action_url: opts[:action_url],
      metadata: opts[:metadata] || %{}
    })
  end
end
