defmodule Shomp.Repo.Migrations.AddUniversalOrderIdToDownloads do
  use Ecto.Migration

  def change do
    # Add universal_order_id column to downloads table
    alter table(:downloads) do
      add :universal_order_id, :string, null: true
    end

    # Create index for better query performance
    create index(:downloads, [:universal_order_id])
  end
end
