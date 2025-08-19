defmodule Shomp.Repo.Migrations.UpdateCartsStoreReference do
  use Ecto.Migration

  def up do
    # Add the new store_id field as a string (initially nullable)
    alter table(:carts) do
      add :store_uuid, :string
    end

    # Populate the new field with store_id from the stores table
    execute """
    UPDATE carts 
    SET store_uuid = stores.store_id 
    FROM stores 
    WHERE carts.store_id = stores.id
    """

    # Remove the old foreign key constraint and column
    alter table(:carts) do
      remove :store_id
    end

    # Rename the new field to store_id
    rename table(:carts), :store_uuid, to: :store_id

    # Make the new store_id field not null
    alter table(:carts) do
      modify :store_id, :string, null: false
    end

    # Create index on the new store_id field
    create index(:carts, [:store_id])
  end

  def down do
    # This is a destructive migration, so rollback recreates the foreign key
    alter table(:carts) do
      remove :store_id
    end

    alter table(:carts) do
      add :store_id, references(:stores, on_delete: :delete_all), null: false
    end

    create index(:carts, [:store_id])
  end
end
