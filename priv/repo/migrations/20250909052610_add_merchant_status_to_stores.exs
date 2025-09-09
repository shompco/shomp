defmodule Shomp.Repo.Migrations.AddMerchantStatusToStores do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :merchant_status, :string, default: "pending_verification", null: false
      add :pending_balance, :decimal, precision: 10, scale: 2, default: 0
      add :available_balance, :decimal, precision: 10, scale: 2, default: 0
    end

    create index(:stores, [:merchant_status])
  end
end