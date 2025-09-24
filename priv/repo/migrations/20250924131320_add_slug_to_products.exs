defmodule Shomp.Repo.Migrations.AddSlugToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :slug, :string
    end

    create index(:products, [:slug])
  end
end
