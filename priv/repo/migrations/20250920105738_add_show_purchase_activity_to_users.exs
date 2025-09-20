defmodule Shomp.Repo.Migrations.AddShowPurchaseActivityToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :show_purchase_activity, :boolean, default: true
    end
  end
end