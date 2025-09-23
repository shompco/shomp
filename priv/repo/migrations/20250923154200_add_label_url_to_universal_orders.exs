defmodule Shomp.Repo.Migrations.AddLabelUrlToUniversalOrders do
  use Ecto.Migration

  def change do
    alter table(:universal_orders) do
      add :label_url, :string
    end
  end
end
