defmodule Shomp.Repo.Migrations.AddProductUrlToPurchaseActivities do
  use Ecto.Migration

  def change do
    alter table(:purchase_activities) do
      add :product_url, :string
    end
  end
end
