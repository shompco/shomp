defmodule Shomp.Repo.Migrations.CreatePurchaseActivities do
  use Ecto.Migration

  def change do
    create table(:purchase_activities, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :order_id, references(:universal_orders, type: :binary_id), null: false
      add :product_id, references(:products, type: :bigserial), null: false
      add :buyer_id, references(:users, type: :bigserial), null: false
      add :buyer_initials, :string, null: false
      add :buyer_location, :string, null: true # "San Francisco, CA"
      add :product_title, :string, null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :is_public, :boolean, default: true
      add :displayed_at, :utc_datetime, null: true
      add :display_count, :integer, default: 0
      
      timestamps()
    end

    create index(:purchase_activities, [:inserted_at])
    create index(:purchase_activities, [:is_public])
    create index(:purchase_activities, [:displayed_at])
    create index(:purchase_activities, [:order_id])
  end
end