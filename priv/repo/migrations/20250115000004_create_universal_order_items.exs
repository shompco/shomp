defmodule Shomp.Repo.Migrations.CreateUniversalOrderItems do
  use Ecto.Migration

  def change do
    create table(:universal_order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_item_id, :string, null: false  # e.g., "OI_20240115_ABC123"
      add :universal_order_id, :string, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :store_id, :string, null: false
      add :quantity, :integer, default: 1, null: false
      add :unit_price, :decimal, precision: 10, scale: 2, null: false
      add :total_price, :decimal, precision: 10, scale: 2, null: false
      add :store_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: 0
      add :payment_split_id, :string
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:universal_order_items, [:order_item_id])
    create index(:universal_order_items, [:universal_order_id])
    create index(:universal_order_items, [:product_id])
    create index(:universal_order_items, [:store_id])
  end
end
