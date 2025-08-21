defmodule Shomp.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :immutable_id, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :status, :string, default: "pending", null: false
      add :stripe_session_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:orders, [:immutable_id])
    create index(:orders, [:user_id])
    create index(:orders, [:stripe_session_id])
    create index(:orders, [:status])

    # Create order_items table
    create table(:order_items) do
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :quantity, :integer, default: 1, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :created_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:product_id])
  end
end
