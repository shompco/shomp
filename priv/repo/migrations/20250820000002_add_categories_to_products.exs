defmodule Shomp.Repo.Migrations.AddCategoriesToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :category_id, references(:categories, on_delete: :restrict)
      add :subcategory_id, references(:categories, on_delete: :restrict)
    end

    create index(:products, [:category_id])
    create index(:products, [:subcategory_id])
  end
end
