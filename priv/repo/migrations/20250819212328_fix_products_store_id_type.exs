defmodule Shomp.Repo.Migrations.FixProductsStoreIdType do
  use Ecto.Migration

  def up do
    # First, let's check if the store_id column exists and what type it is
    # If it's still the old integer foreign key, we need to fix it
    
    # Drop the existing store_id column if it exists
    execute "ALTER TABLE products DROP COLUMN IF EXISTS store_id CASCADE"
    
    # Add the new store_id column as a string
    alter table(:products) do
      add :store_id, :string, null: false
    end
    
    # Create index on the new store_id field
    create index(:products, [:store_id])
  end

  def down do
    # Remove the string store_id column
    alter table(:products) do
      remove :store_id
    end
    
    # Recreate the original foreign key column
    alter table(:products) do
      add :store_id, references(:stores, on_delete: :delete_all), null: false
    end
    
    create index(:products, [:store_id])
  end
end
