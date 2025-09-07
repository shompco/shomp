defmodule Shomp.SupportTickets do
  @moduledoc """
  The SupportTickets context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.SupportTickets.{SupportTicket, SupportMessage}

  def list_user_tickets(user_id, filters \\ %{}) do
    SupportTicket
    |> where([t], t.user_id == ^user_id)
    |> apply_filters(filters)
    |> preload([:user, :order, :store, :assigned_to_user, :resolved_by_user])
    |> order_by([t], [desc: t.last_activity_at, desc: t.inserted_at])
    |> Repo.all()
  end

  def list_admin_tickets(filters \\ %{}) do
    SupportTicket
    |> apply_filters(filters)
    |> preload([:user, :order, :store, :assigned_to_user, :resolved_by_user])
    |> order_by([t], [desc: t.last_activity_at, desc: t.inserted_at])
    |> Repo.all()
  end

  def get_ticket!(id) do
    SupportTicket
    |> preload([:user, :order, :store, :assigned_to_user, :resolved_by_user, :messages])
    |> Repo.get!(id)
  end

  def get_ticket_by_ticket_number!(ticket_number) do
    SupportTicket
    |> preload([:user, :order, :store, :assigned_to_user, :resolved_by_user, :messages])
    |> Repo.get_by!(ticket_number: ticket_number)
  end

  def create_ticket(attrs \\ %{}) do
    ticket_number = generate_ticket_number()
    
    case %SupportTicket{}
         |> SupportTicket.changeset(Map.put(attrs, "ticket_number", ticket_number))
         |> Repo.insert() do
      {:ok, ticket} ->
        # Broadcast ticket creation to admin dashboard
        Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:support_tickets", %{
          event: "support_ticket_created",
          payload: ticket
        })
        {:ok, ticket}
      
      error -> error
    end
  end

  def update_ticket(ticket, attrs) do
    case ticket
         |> SupportTicket.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_ticket} ->
        # Broadcast ticket update to admin dashboard
        Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:support_tickets", %{
          event: "support_ticket_updated",
          payload: updated_ticket
        })
        {:ok, updated_ticket}
      
      error -> error
    end
  end

  def assign_ticket(ticket, admin_user_id) do
    ticket
    |> SupportTicket.assignment_changeset(%{assigned_to_user_id: admin_user_id})
    |> Repo.update()
  end

  def resolve_ticket(ticket, admin_user_id, resolution_notes) do
    case ticket
         |> SupportTicket.resolution_changeset(%{
           status: "resolved",
           resolved_at: DateTime.utc_now(),
           resolved_by_user_id: admin_user_id,
           resolution_notes: resolution_notes
         })
         |> Repo.update() do
      {:ok, updated_ticket} ->
        # Broadcast ticket update to admin dashboard
        Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:support_tickets", %{
          event: "support_ticket_updated",
          payload: updated_ticket
        })
        {:ok, updated_ticket}
      
      error -> error
    end
  end

  def add_message(ticket, message_attrs) do
    %SupportMessage{}
    |> SupportMessage.changeset(Map.put(message_attrs, "support_ticket_id", ticket.id))
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # Update ticket last activity
        update_ticket(ticket, %{last_activity_at: DateTime.utc_now()})
        {:ok, message}
      error -> error
    end
  end

  def count_tickets(filters \\ %{}) do
    SupportTicket
    |> apply_filters(filters)
    |> Repo.aggregate(:count)
  end

  def count_tickets_resolved_today do
    today = Date.utc_today()
    
    SupportTicket
    |> where([t], t.status == "resolved" and fragment("DATE(?) = ?", t.resolved_at, ^today))
    |> Repo.aggregate(:count)
  end

  def avg_resolution_time_hours do
    # This would need a more complex query to calculate average resolution time
    # For now, return a placeholder
    24.0
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, query when status != "" ->
        where(query, [t], t.status == ^status)
      {:priority, priority}, query when priority != "" ->
        where(query, [t], t.priority == ^priority)
      {:category, category}, query when category != "" ->
        where(query, [t], t.category == ^category)
      {:assigned_to, user_id}, query when user_id != "" ->
        where(query, [t], t.assigned_to_user_id == ^user_id)
      _, query -> query
    end)
  end

  defp generate_ticket_number do
    # Generate format: ST-YYYYMMDD-XXXX
    date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    random = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
    "ST-#{date}-#{random}"
  end
end
