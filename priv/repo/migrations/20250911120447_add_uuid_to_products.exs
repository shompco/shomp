defmodule Shomp.Repo.Migrations.AddUuidToProducts do
  use Ecto.Migration

  def up do
    # Add immutable_id column to products
    alter table(:products) do
      add :immutable_id, :binary_id, null: false, default: fragment("gen_random_uuid()")
    end

    # Create unique index on immutable_id
    create unique_index(:products, [:immutable_id])

    # Update all existing products to have immutable_id
    execute "UPDATE products SET immutable_id = gen_random_uuid() WHERE immutable_id IS NULL"

    # Make immutable_id not null after populating
    alter table(:products) do
      modify :immutable_id, :binary_id, null: false
    end

    # Update foreign key references in other tables
    # First, add new columns for the UUID references
    alter table(:cart_items) do
      add :product_immutable_id, :binary_id
    end

    alter table(:downloads) do
      add :product_immutable_id, :binary_id
    end

    alter table(:order_items) do
      add :product_immutable_id, :binary_id
    end

    alter table(:payments) do
      add :product_immutable_id, :binary_id
    end

    alter table(:reviews) do
      add :product_immutable_id, :binary_id
    end

    alter table(:universal_order_items) do
      add :product_immutable_id, :binary_id
    end

    # Populate the new columns with the corresponding immutable_ids
    execute """
    UPDATE cart_items
    SET product_immutable_id = p.immutable_id
    FROM products p
    WHERE cart_items.product_id = p.id
    """

    execute """
    UPDATE downloads
    SET product_immutable_id = p.immutable_id
    FROM products p
    WHERE downloads.product_id = p.id
    """

    execute """
    UPDATE order_items
    SET product_immutable_id = p.immutable_id
    FROM products p
    WHERE order_items.product_id = p.id
    """

    execute """
    UPDATE payments
    SET product_immutable_id = p.immutable_id
    FROM products p
    WHERE payments.product_id = p.id
    """

    execute """
    UPDATE reviews
    SET product_immutable_id = p.immutable_id
    FROM products p
    WHERE reviews.product_id = p.id
    """

    execute """
    UPDATE universal_order_items
    SET product_immutable_id = p.immutable_id
    FROM products p
    WHERE universal_order_items.product_id = p.id
    """

    # Make the new columns not null
    alter table(:cart_items) do
      modify :product_immutable_id, :binary_id, null: false
    end

    alter table(:downloads) do
      modify :product_immutable_id, :binary_id, null: false
    end

    alter table(:order_items) do
      modify :product_immutable_id, :binary_id, null: false
    end

    alter table(:payments) do
      modify :product_immutable_id, :binary_id, null: false
    end

    alter table(:reviews) do
      modify :product_immutable_id, :binary_id, null: false
    end

    alter table(:universal_order_items) do
      modify :product_immutable_id, :binary_id, null: false
    end

    # Create foreign key constraints for the new columns
    execute "ALTER TABLE cart_items ADD CONSTRAINT cart_items_product_immutable_id_fkey FOREIGN KEY (product_immutable_id) REFERENCES products(immutable_id) ON DELETE CASCADE"
    execute "ALTER TABLE downloads ADD CONSTRAINT downloads_product_immutable_id_fkey FOREIGN KEY (product_immutable_id) REFERENCES products(immutable_id) ON DELETE CASCADE"
    execute "ALTER TABLE order_items ADD CONSTRAINT order_items_product_immutable_id_fkey FOREIGN KEY (product_immutable_id) REFERENCES products(immutable_id) ON DELETE CASCADE"
    execute "ALTER TABLE payments ADD CONSTRAINT payments_product_immutable_id_fkey FOREIGN KEY (product_immutable_id) REFERENCES products(immutable_id) ON DELETE CASCADE"
    execute "ALTER TABLE reviews ADD CONSTRAINT reviews_product_immutable_id_fkey FOREIGN KEY (product_immutable_id) REFERENCES products(immutable_id) ON DELETE CASCADE"
    execute "ALTER TABLE universal_order_items ADD CONSTRAINT universal_order_items_product_immutable_id_fkey FOREIGN KEY (product_immutable_id) REFERENCES products(immutable_id) ON DELETE CASCADE"

    # Create indexes for the new foreign keys
    create index(:cart_items, [:product_immutable_id])
    create index(:downloads, [:product_immutable_id])
    create index(:order_items, [:product_immutable_id])
    create index(:payments, [:product_immutable_id])
    create index(:reviews, [:product_immutable_id])
    create index(:universal_order_items, [:product_immutable_id])
  end

  def down do
    # Remove the new foreign key constraints and columns
    drop constraint(:cart_items, "cart_items_product_immutable_id_fkey")
    drop constraint(:downloads, "downloads_product_immutable_id_fkey")
    drop constraint(:order_items, "order_items_product_immutable_id_fkey")
    drop constraint(:payments, "payments_product_immutable_id_fkey")
    drop constraint(:reviews, "reviews_product_immutable_id_fkey")
    drop constraint(:universal_order_items, "universal_order_items_product_immutable_id_fkey")

    drop index(:cart_items, [:product_immutable_id])
    drop index(:downloads, [:product_immutable_id])
    drop index(:order_items, [:product_immutable_id])
    drop index(:payments, [:product_immutable_id])
    drop index(:reviews, [:product_immutable_id])
    drop index(:universal_order_items, [:product_immutable_id])

    alter table(:cart_items) do
      remove :product_immutable_id
    end

    alter table(:downloads) do
      remove :product_immutable_id
    end

    alter table(:order_items) do
      remove :product_immutable_id
    end

    alter table(:payments) do
      remove :product_immutable_id
    end

    alter table(:reviews) do
      remove :product_immutable_id
    end

    alter table(:universal_order_items) do
      remove :product_immutable_id
    end

    # Remove immutable_id from products
    drop index(:products, [:immutable_id])
    alter table(:products) do
      remove :immutable_id
    end
  end
end
