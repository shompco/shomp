defmodule Shomp.Repo.Migrations.MarkExistingStoresAsDefault do
  use Ecto.Migration

  def up do
    # Mark the first store for each user as default
    execute """
    UPDATE stores
    SET is_default = true
    WHERE id IN (
      SELECT DISTINCT ON (user_id) id
      FROM stores
      ORDER BY user_id, inserted_at ASC
    )
    """
  end

  def down do
    execute "UPDATE stores SET is_default = false"
  end
end
