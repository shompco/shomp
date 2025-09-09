defmodule Shomp.Repo.Migrations.MakeStripeAccountIdNullableInPaymentSplits do
  use Ecto.Migration

  def change do
    alter table(:payment_splits) do
      modify :stripe_account_id, :string, null: true
    end
  end
end