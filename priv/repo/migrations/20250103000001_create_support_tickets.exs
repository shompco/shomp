defmodule Shomp.Repo.Migrations.CreateSupportTickets do
  use Ecto.Migration

  def change do
    create table(:support_tickets) do
      add :ticket_number, :string, null: false
      add :subject, :string, null: false
      add :description, :text, null: false
      add :status, :string, default: "open" # open, in_progress, waiting_customer, resolved, closed
      add :priority, :string, default: "medium" # low, medium, high, urgent
      add :category, :string, null: false # order_issue, payment_issue, technical, account, other
      add :subcategory, :string # order_cancellation, refund_request, login_issue, etc.
      
      # User and order references
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :order_id, references(:orders, on_delete: :nilify_all)
      add :store_id, references(:stores, on_delete: :nilify_all)
      
      # Assignment and resolution
      add :assigned_to_user_id, references(:users, on_delete: :nilify_all)
      add :resolved_at, :utc_datetime
      add :resolved_by_user_id, references(:users, on_delete: :nilify_all)
      add :resolution_notes, :text
      
      # Internal tracking
      add :internal_notes, :text
      add :last_activity_at, :utc_datetime, default: fragment("NOW()")
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:support_tickets, [:ticket_number])
    create index(:support_tickets, [:user_id])
    create index(:support_tickets, [:status])
    create index(:support_tickets, [:priority])
    create index(:support_tickets, [:assigned_to_user_id])
    create index(:support_tickets, [:last_activity_at])
  end
end
