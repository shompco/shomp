defmodule Shomp.Repo.Migrations.AddImmutableIdAndPriorityToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :immutable_id, :string, null: false
      add :priority, :string, default: "normal", null: false
    end

    create unique_index(:notifications, [:immutable_id])
    create index(:notifications, [:priority])
  end
end
