defmodule Shomp.Repo.Migrations.CreateRefunds do
  use Ecto.Migration

  def change do
    create table(:refunds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :refund_id, :string, null: false  # e.g., "RF_20240115_ABC123"
      add :universal_order_id, :string, null: false
      add :payment_split_id, :string, null: false
      add :store_id, :string, null: false  # Store being debited
      add :stripe_refund_id, :string, null: false
      add :refund_amount, :decimal, precision: 10, scale: 2, null: false
      add :refund_reason, :string, null: false
      add :refund_type, :string, null: false  # full, partial, item_specific
      add :status, :string, default: "pending", null: false
      add :processed_at, :utc_datetime
      add :stripe_charge_id, :string
      add :admin_notes, :text
      add :processed_by_user_id, references(:users, on_delete: :nilify_all)
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:refunds, [:refund_id])
    create unique_index(:refunds, [:stripe_refund_id])
    create index(:refunds, [:universal_order_id])
    create index(:refunds, [:payment_split_id])
    create index(:refunds, [:store_id])
    create index(:refunds, [:status])
  end
end
