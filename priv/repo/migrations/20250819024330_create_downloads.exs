defmodule Shomp.Repo.Migrations.CreateDownloads do
  use Ecto.Migration

  def change do
    create table(:downloads) do
      add :token, :string, null: false
      add :download_count, :integer, default: 0, null: false
      add :expires_at, :utc_datetime
      add :last_downloaded_at, :utc_datetime
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    # Indexes for performance and constraints
    create unique_index(:downloads, [:token])
    create index(:downloads, [:product_id])
    create index(:downloads, [:user_id])
    create index(:downloads, [:expires_at])
    create index(:downloads, [:inserted_at])
  end
end
