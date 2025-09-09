defmodule Shomp.Repo.Migrations.CreatePaymentSplits do
  use Ecto.Migration

  def change do
    create table(:payment_splits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :payment_split_id, :string, null: false  # e.g., "PS_20240115_ABC123"
      add :universal_order_id, :string, null: false
      add :stripe_payment_intent_id, :string, null: false
      add :store_id, :string, null: false
      add :stripe_account_id, :string, null: false
      add :store_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: 0
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :stripe_transfer_id, :string
      add :transfer_status, :string, default: "pending"
      add :refunded_amount, :decimal, precision: 10, scale: 2, default: 0
      add :refund_status, :string, default: "none"
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:payment_splits, [:payment_split_id])
    create index(:payment_splits, [:universal_order_id])
    create index(:payment_splits, [:store_id])
    create index(:payment_splits, [:stripe_account_id])
    create index(:payment_splits, [:transfer_status])
    create index(:payment_splits, [:refund_status])
  end
end
