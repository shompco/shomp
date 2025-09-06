defmodule Shomp.Repo.Migrations.CreateSupportMessages do
  use Ecto.Migration

  def change do
    create table(:support_messages) do
      add :support_ticket_id, references(:support_tickets, on_delete: :delete_all), null: false
      add :message, :text, null: false
      add :is_internal, :boolean, default: false # Internal admin notes
      add :is_from_admin, :boolean, default: false
      add :author_user_id, references(:users, on_delete: :delete_all), null: false
      
      # File attachments
      add :attachments, :map, default: %{} # JSON field for file references
      
      timestamps(type: :utc_datetime)
    end

    create index(:support_messages, [:support_ticket_id])
    create index(:support_messages, [:author_user_id])
    create index(:support_messages, [:inserted_at])
  end
end
