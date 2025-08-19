defmodule Shomp.Repo.Migrations.CreateCartItems do
  use Ecto.Migration

  def change do
    create table(:cart_items) do
      add :quantity, :integer, null: false, default: 1
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :cart_id, references(:carts, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false

      timestamps()
    end

    # Indexes for performance and constraints
    create index(:cart_items, [:cart_id])
    create index(:cart_items, [:product_id])
    create index(:cart_items, [:inserted_at])
    
    # Ensure unique product per cart (can update quantity instead)
    create unique_index(:cart_items, [:cart_id, :product_id])
  end
end
