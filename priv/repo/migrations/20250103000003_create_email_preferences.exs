defmodule Shomp.Repo.Migrations.CreateEmailPreferences do
  use Ecto.Migration

  def change do
    create table(:email_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      
      # Order notifications
      add :order_confirmation, :boolean, default: true
      add :order_status_updates, :boolean, default: true
      add :shipping_notifications, :boolean, default: true
      add :delivery_confirmation, :boolean, default: true
      
      # Support notifications
      add :support_ticket_updates, :boolean, default: true
      add :support_ticket_resolved, :boolean, default: true
      
      # Marketing notifications
      add :product_updates, :boolean, default: false
      add :promotional_emails, :boolean, default: false
      add :newsletter, :boolean, default: false
      
      # System notifications
      add :security_alerts, :boolean, default: true
      add :account_updates, :boolean, default: true
      add :system_maintenance, :boolean, default: true
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_preferences, [:user_id])
  end
end
