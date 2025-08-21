defmodule Shomp.Repo.Migrations.FixOrderItemsTimestamps do
  use Ecto.Migration

  def change do
    # Remove the duplicate created_at column from order_items table
    # The timestamps() macro already creates inserted_at and updated_at
    alter table(:order_items) do
      remove :created_at
    end
  end
end
