defmodule Shomp.Repo.Migrations.CreateDonationGoals do
  use Ecto.Migration

  def change do
    create table(:donation_goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text, null: false
      add :target_amount, :decimal, precision: 10, scale: 2, null: false
      add :current_amount, :decimal, precision: 10, scale: 2, default: 0.0
      add :status, :string, default: "active" # active, completed, paused

      timestamps(type: :utc_datetime)
    end

    create index(:donation_goals, [:status])
    create index(:donation_goals, [:inserted_at])
  end
end
