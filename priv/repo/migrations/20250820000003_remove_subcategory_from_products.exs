defmodule Shomp.Repo.Migrations.RemoveSubcategoryFromProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      remove :subcategory_id
    end
  end
end
