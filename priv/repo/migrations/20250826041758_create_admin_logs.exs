defmodule Shomp.Repo.Migrations.CreateAdminLogs do
  use Ecto.Migration

  def change do
    create table(:admin_logs) do
      add :admin_user_id, :integer, null: false
      add :entity_type, :string, null: false
      add :entity_id, :integer, null: false
      add :action, :string, null: false
      add :details, :text, null: false
      add :metadata, :map

      timestamps()
    end

    # Add indexes for better query performance
    create index(:admin_logs, [:admin_user_id])
    create index(:admin_logs, [:entity_type, :entity_id])
    create index(:admin_logs, [:action])
    create index(:admin_logs, [:inserted_at])
  end
end
