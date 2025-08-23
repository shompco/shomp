defmodule Shomp.Repo.Migrations.CreateEmailSubscriptions do
  use Ecto.Migration

  def change do
    create table(:email_subscriptions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :string, null: false
      add :source, :string, default: "landing_page"
      add :subscribed_at, :utc_datetime, null: false
      add :unsubscribed_at, :utc_datetime
      add :status, :string, default: "active"
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:email_subscriptions, [:email])
    create index(:email_subscriptions, [:status])
    create index(:email_subscriptions, [:subscribed_at])
  end
end
