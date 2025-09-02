defmodule Shomp.Repo.Migrations.AddStripeIndividualInfoToStoreKyc do
  use Ecto.Migration

  def change do
    alter table(:store_kyc) do
      add :stripe_individual_info, :map, default: %{}
    end
  end
end
