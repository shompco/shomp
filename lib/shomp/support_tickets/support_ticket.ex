defmodule Shomp.SupportTickets.SupportTicket do
  use Ecto.Schema
  import Ecto.Changeset

  schema "support_tickets" do
    field :ticket_number, :string
    field :subject, :string
    field :description, :string
    field :status, :string, default: "open"
    field :priority, :string, default: "medium"
    field :category, :string
    field :subcategory, :string
    field :resolution_notes, :string
    field :internal_notes, :string
    field :last_activity_at, :utc_datetime
    field :resolved_at, :utc_datetime

    belongs_to :user, Shomp.Accounts.User
    belongs_to :order, Shomp.Orders.Order
    belongs_to :store, Shomp.Stores.Store
    belongs_to :assigned_to_user, Shomp.Accounts.User
    belongs_to :resolved_by_user, Shomp.Accounts.User

    has_many :messages, Shomp.SupportTickets.SupportMessage

    timestamps(type: :utc_datetime)
  end

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:ticket_number, :subject, :description, :status, :priority, :category, :subcategory, :user_id, :order_id, :store_id, :internal_notes])
    |> validate_required([:ticket_number, :subject, :description, :category, :user_id])
    |> validate_inclusion(:status, ["open", "in_progress", "waiting_customer", "resolved", "closed"])
    |> validate_inclusion(:priority, ["low", "medium", "high", "urgent"])
    |> validate_inclusion(:category, ["order_issue", "payment_issue", "technical", "account", "other"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:store_id)
  end

  def assignment_changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:assigned_to_user_id, :status])
    |> foreign_key_constraint(:assigned_to_user_id)
  end

  def resolution_changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:status, :resolved_at, :resolved_by_user_id, :resolution_notes])
    |> foreign_key_constraint(:resolved_by_user_id)
  end
end
