defmodule Shomp.Repo.Migrations.AddOrderStatusFields do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      # Essential status fields for order management
      add :fulfillment_status, :string, default: "unfulfilled"
      add :payment_status, :string, default: "pending" 
      add :shipped_at, :utc_datetime
    end

    create index(:orders, [:fulfillment_status])
    create index(:orders, [:payment_status])
  end
end