defmodule Shomp.Repo.Migrations.AddCustomCategoryIdToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :custom_category_id, references(:categories, on_delete: :restrict)
    end

    create index(:products, [:custom_category_id])
  end
end
