defmodule Shomp.Repo.Migrations.FixProductIdConstraints do
  use Ecto.Migration

  def up do
    # Make product_id nullable in universal_order_items
    alter table(:universal_order_items) do
      modify :product_id, :bigint, null: true
    end

    # Ensure product_immutable_id is not null
    alter table(:universal_order_items) do
      modify :product_immutable_id, :binary_id, null: false
    end
  end

  def down do
    # Revert back to original constraints
    alter table(:universal_order_items) do
      modify :product_id, :bigint, null: false
    end

    alter table(:universal_order_items) do
      modify :product_immutable_id, :binary_id, null: true
    end
  end
end
