defmodule Shomp.Repo.Migrations.AddCountryToStoreKyc do
  use Ecto.Migration

  def change do
    alter table(:store_kyc) do
      add :country, :string
    end
  end
end
