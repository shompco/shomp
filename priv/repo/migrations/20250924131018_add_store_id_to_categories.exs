defmodule Shomp.Repo.Migrations.AddStoreIdToCategories do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :store_id, :string
    end

    create index(:categories, [:store_id])
  end
end
