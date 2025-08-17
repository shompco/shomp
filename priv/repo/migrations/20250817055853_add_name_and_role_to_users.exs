defmodule Shomp.Repo.Migrations.AddNameAndRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string, null: false
      add :role, :string, default: "user", null: false
    end
  end
end
