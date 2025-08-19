defmodule Shomp.Repo.Migrations.CreateCarts do
  use Ecto.Migration

  def change do
    create table(:carts) do
      add :status, :string, null: false, default: "active"
      add :total_amount, :decimal, precision: 10, scale: 2, default: 0.0, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :store_id, references(:stores, on_delete: :delete_all), null: false

      timestamps()
    end

    # Indexes for performance and constraints
    create index(:carts, [:user_id])
    create index(:carts, [:store_id])
    create index(:carts, [:status])
    create index(:carts, [:inserted_at])
    
    # Ensure one active cart per user per store
    create unique_index(:carts, [:user_id, :store_id], where: "status = 'active'")
  end
end
