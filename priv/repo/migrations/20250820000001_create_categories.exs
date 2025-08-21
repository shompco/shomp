defmodule Shomp.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :position, :integer, default: 0, null: false
      add :level, :integer, default: 0, null: false
      add :active, :boolean, default: true, null: false
      add :parent_id, references(:categories, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    create index(:categories, [:parent_id])
    create index(:categories, [:level])
    create unique_index(:categories, [:slug])
  end
end
