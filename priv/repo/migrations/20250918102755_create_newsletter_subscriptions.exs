defmodule Shomp.Repo.Migrations.CreateNewsletterSubscriptions do
  use Ecto.Migration

  def change do
    create table(:newsletter_subscriptions) do
      add :email, :string, null: false
      add :subscribed_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :unsubscribed_at, :utc_datetime
      add :status, :string, null: false, default: "active"
      add :source, :string, default: "website"
      add :beehiiv_subscriber_id, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:newsletter_subscriptions, [:email])
    create index(:newsletter_subscriptions, [:status])
    create index(:newsletter_subscriptions, [:subscribed_at])
    create index(:newsletter_subscriptions, [:beehiiv_subscriber_id])
  end
end
