defmodule Shomp.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :bio, :text
      add :location, :string
      add :website, :string
      add :verified, :boolean, default: false
    end
  end
end
