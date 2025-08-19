defmodule Shomp.Repo.Migrations.AddStoreIdToStores do
  use Ecto.Migration

  def up do
    # Add the immutable store_id field (initially nullable)
    alter table(:stores) do
      add :store_id, :string
    end

    # Populate store_id for existing stores with their current id
    execute "UPDATE stores SET store_id = id::text"
    
    # Now make it not null
    alter table(:stores) do
      modify :store_id, :string, null: false
    end

    # Create a unique index on store_id
    create unique_index(:stores, [:store_id])
  end

  def down do
    # Remove the store_id field
    alter table(:stores) do
      remove :store_id
    end
  end
end
