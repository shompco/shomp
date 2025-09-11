defmodule Shomp.Repo.Migrations.AddStripeCountryToStoreKyc do
  use Ecto.Migration

  def change do
    alter table(:store_kyc) do
      add :stripe_country, :string
    end

    create index(:store_kyc, [:stripe_country])
  end
end
