defmodule Shomp.Repo.Migrations.CreateRequests do
  use Ecto.Migration

  def change do
    create table(:requests) do
      add :title, :string
      add :description, :text
      add :category, :string
      add :status, :string
      add :priority, :integer
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:requests, [:user_id])
  end
end
