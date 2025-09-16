defmodule Shomp.Repo.Migrations.AddProductIndexesForPerformance do
  use Ecto.Migration

  def change do
    # Add composite index for category_id and inserted_at for efficient ordering
    create index(:products, [:category_id, :inserted_at])

    # Add composite index for custom_category_id and inserted_at for efficient ordering
    create index(:products, [:custom_category_id, :inserted_at])

    # Add index for store_id and inserted_at for efficient store product queries
    create index(:products, [:store_id, :inserted_at])
  end
end
