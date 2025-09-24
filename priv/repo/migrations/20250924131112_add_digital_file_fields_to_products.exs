defmodule Shomp.Repo.Migrations.AddDigitalFileFieldsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :digital_file_url, :string
      add :digital_file_type, :string
    end
  end
end
