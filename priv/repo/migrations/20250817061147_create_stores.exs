defmodule Shomp.Repo.Migrations.CreateStores do
  use Ecto.Migration

  def change do
    create table(:stores) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stores, [:slug])
    create index(:stores, [:user_id])
  end
end
