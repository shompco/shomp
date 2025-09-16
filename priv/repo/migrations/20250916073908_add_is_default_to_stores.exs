defmodule Shomp.Repo.Migrations.AddIsDefaultToStores do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :is_default, :boolean, default: false, null: false
    end

    # Ensure only one default store per user
    create unique_index(:stores, [:user_id, :is_default],
           where: "is_default = true",
           name: :stores_user_default_unique)
  end
end
