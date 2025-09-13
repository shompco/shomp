defmodule Shomp.Repo.Migrations.FixDownloadsProductIdConstraints do
  use Ecto.Migration

  def up do
    # Make product_id nullable in downloads table
    alter table(:downloads) do
      modify :product_id, :bigint, null: true
    end

    # Ensure product_immutable_id is not null
    alter table(:downloads) do
      modify :product_immutable_id, :binary_id, null: false
    end
  end

  def down do
    # Revert back to original constraints
    alter table(:downloads) do
      modify :product_id, :bigint, null: false
    end

    alter table(:downloads) do
      modify :product_immutable_id, :binary_id, null: true
    end
  end
end
