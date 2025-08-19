defmodule Shomp.Repo.Migrations.CreateStoreBalances do
  use Ecto.Migration

  def change do
    create table(:store_balances) do
      add :total_earnings, :decimal, precision: 10, scale: 2, default: 0.0, null: false
      add :pending_balance, :decimal, precision: 10, scale: 2, default: 0.0, null: false
      add :paid_out_balance, :decimal, precision: 10, scale: 2, default: 0.0, null: false
      add :last_payout_date, :utc_datetime
      add :kyc_verified, :boolean, default: false, null: false
      add :kyc_verified_at, :utc_datetime
      add :kyc_documents_submitted, :boolean, default: false, null: false
      add :kyc_submitted_at, :utc_datetime
      add :store_id, references(:stores, on_delete: :delete_all), null: false

      timestamps()
    end

    # Indexes for performance and constraints
    create index(:store_balances, [:kyc_verified])
    create index(:store_balances, [:pending_balance])
    create unique_index(:store_balances, [:store_id])
  end
end
