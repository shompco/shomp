defmodule Shomp.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :message, :text, null: false
      add :type, :string, null: false # "order_update", "support_ticket", "system", etc.
      add :read, :boolean, default: false
      add :action_url, :string # Optional URL to navigate to when clicked
      add :metadata, :map, default: %{} # Additional data for the notification
      
      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:read])
    create index(:notifications, [:type])
    create index(:notifications, [:inserted_at])
  end
end