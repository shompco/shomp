defmodule Shomp.Repo.Migrations.AddUsernameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
    end

    # Create unique index on username
    create unique_index(:users, [:username])
  end
end
