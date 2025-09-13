defmodule Shomp.Repo.Migrations.AddOrderItemIdToDownloads do
  use Ecto.Migration

  def up do
    # Add order_item_id column to downloads table
    alter table(:downloads) do
      add :order_item_id, :integer, null: true
    end

    # Create index for better query performance
    create index(:downloads, [:order_item_id])
  end

  def down do
    # Remove the index first
    drop index(:downloads, [:order_item_id])

    # Remove the column
    alter table(:downloads) do
      remove :order_item_id
    end
  end
end
