defmodule Shomp.Repo.Migrations.RemoveCategoryFromRequests do
  use Ecto.Migration

  def change do
    alter table(:requests) do
      remove :category
    end
  end
end
