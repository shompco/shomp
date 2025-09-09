defmodule Shomp.Repo.Migrations.CreateUniversalOrders do
  use Ecto.Migration

  def change do
    create table(:universal_orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :universal_order_id, :string, null: false  # e.g., "UO_20240115_ABC123"
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :stripe_payment_intent_id, :string, null: false
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: 0
      add :status, :string, default: "pending", null: false
      add :payment_status, :string, default: "pending", null: false
      add :billing_address_id, references(:addresses, on_delete: :nilify_all)
      add :shipping_address_id, references(:addresses, on_delete: :nilify_all)
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:universal_orders, [:universal_order_id])
    create unique_index(:universal_orders, [:stripe_payment_intent_id])
    create index(:universal_orders, [:user_id])
    create index(:universal_orders, [:status])
    create index(:universal_orders, [:payment_status])
  end
end
