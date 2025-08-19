defmodule Shomp.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes) do
      add :weight, :integer
      add :request_id, references(:requests, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:votes, [:request_id])
    create index(:votes, [:user_id])
    create unique_index(:votes, [:request_id, :user_id])
  end
end
