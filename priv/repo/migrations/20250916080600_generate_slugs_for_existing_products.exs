defmodule Shomp.Repo.Migrations.GenerateSlugsForExistingProducts do
  use Ecto.Migration

  def up do
    # Generate slugs for products that don't have them
    # Skip for fresh database - no products exist yet
    # execute """
    # UPDATE products
    # SET slug = LOWER(
    #   REGEXP_REPLACE(
    #     REGEXP_REPLACE(title, '[^a-zA-Z0-9\\s]', '', 'g'),
    #     '\\s+', '-', 'g'
    #   )
    # )
    # WHERE slug IS NULL OR slug = ''
    # """
  end

  def down do
    # This migration is not reversible as we can't determine which slugs were auto-generated
    # vs manually set
  end
end
