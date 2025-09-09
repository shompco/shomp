defmodule Shomp.Repo.Migrations.AddEscrowFieldsToPaymentSplits do
  use Ecto.Migration

  def change do
    alter table(:payment_splits) do
      add :is_escrow, :boolean, default: false, null: false
    end

    create index(:payment_splits, [:is_escrow])
  end
end