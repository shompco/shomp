defmodule Shomp.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :title, :string, null: false
      add :description, :text
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :type, :string, null: false
      add :file_path, :string
      add :store_id, references(:stores, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:store_id])
    create index(:products, [:type])
  end
end
