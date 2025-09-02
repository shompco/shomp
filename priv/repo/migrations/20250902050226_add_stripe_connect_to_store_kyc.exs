defmodule Shomp.Repo.Migrations.AddStripeConnectToStoreKyc do
  use Ecto.Migration

  def change do
    alter table(:store_kyc) do
      add :stripe_account_id, :string
      add :charges_enabled, :boolean, default: false
      add :payouts_enabled, :boolean, default: false
      add :requirements, :map, default: %{}
      add :onboarding_completed, :boolean, default: false
    end

    create index(:store_kyc, [:stripe_account_id])
  end
end
