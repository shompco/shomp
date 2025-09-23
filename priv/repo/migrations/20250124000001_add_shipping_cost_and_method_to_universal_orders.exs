defmodule Shomp.Repo.Migrations.AddShippingCostAndMethodToUniversalOrders do
  use Ecto.Migration

  def change do
    alter table(:universal_orders) do
      add :shipping_cost, :decimal, precision: 10, scale: 2
      add :shipping_method_name, :string
    end
  end
end
