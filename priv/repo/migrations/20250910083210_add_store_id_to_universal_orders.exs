defmodule Shomp.Repo.Migrations.AddStoreIdToUniversalOrders do
  use Ecto.Migration

  def change do
    alter table(:universal_orders) do
      add :store_id, :string
    end

    create index(:universal_orders, [:store_id])
  end
end
