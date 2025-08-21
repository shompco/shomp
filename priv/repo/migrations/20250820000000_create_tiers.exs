defmodule Shomp.Repo.Migrations.CreateTiers do
  use Ecto.Migration

  def change do
    create table(:tiers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false, unique: true
      add :store_limit, :integer, null: false
      add :product_limit_per_store, :integer, null: false
      add :monthly_price, :decimal, precision: 10, scale: 2, null: false
      add :features, {:array, :string}, default: []
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:tiers, [:slug])
    create index(:tiers, [:sort_order])

    # Add tier_id to users table
    alter table(:users) do
      add :tier_id, references(:tiers, type: :uuid, on_delete: :restrict)
      add :trial_ends_at, :utc_datetime
    end

    create index(:users, [:tier_id])
  end
end
