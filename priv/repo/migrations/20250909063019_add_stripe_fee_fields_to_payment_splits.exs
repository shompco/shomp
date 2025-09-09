defmodule Shomp.Repo.Migrations.AddStripeFeeFieldsToPaymentSplits do
  use Ecto.Migration

  def change do
    alter table(:payment_splits) do
      add :stripe_fee_amount, :decimal, default: 0, null: false
      add :adjusted_store_amount, :decimal, default: 0, null: false
    end
  end
end