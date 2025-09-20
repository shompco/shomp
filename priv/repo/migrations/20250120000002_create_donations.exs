defmodule Shomp.Repo.Migrations.CreateDonations do
  use Ecto.Migration

  def change do
    create table(:donations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :donation_goal_id, references(:donation_goals, type: :binary_id), null: true
      add :user_id, references(:users, type: :bigserial), null: true
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :stripe_payment_intent_id, :string, null: false
      add :donor_name, :string, null: true # Optional display name
      add :donor_email, :string, null: true
      add :message, :text, null: true # Optional message
      add :is_anonymous, :boolean, default: false
      add :is_public, :boolean, default: true # Show in recent donations
      add :status, :string, default: "completed" # completed, failed, refunded

      timestamps(type: :utc_datetime)
    end

    create index(:donations, [:donation_goal_id])
    create index(:donations, [:user_id])
    create index(:donations, [:status])
    create index(:donations, [:is_public])
    create index(:donations, [:inserted_at]) # For sorting by most recent
    create index(:donations, [:stripe_payment_intent_id])
  end
end
