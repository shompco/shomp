defmodule Shomp.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :content, :text
      add :created_at, :utc_datetime
      add :request_id, references(:requests, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:comments, [:request_id])
    create index(:comments, [:user_id])
  end
end
