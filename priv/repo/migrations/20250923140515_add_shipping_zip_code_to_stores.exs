defmodule Shomp.Repo.Migrations.AddShippingZipCodeToStores do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :shipping_zip_code, :string
    end
  end
end
