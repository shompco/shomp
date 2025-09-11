defmodule Shomp.Repo.Migrations.AddTrackingFieldsToUniversalOrders do
  use Ecto.Migration

  def up do
    alter table(:universal_orders) do
      # Enhanced order status fields
      add :fulfillment_status, :string, default: "unfulfilled"
      add :shipped_at, :utc_datetime

      # Physical goods tracking
      add :shipping_status, :string, default: "ordered"
      add :tracking_number, :string
      add :carrier, :string
      add :estimated_delivery, :date
      add :delivered_at, :utc_datetime

      # Additional shipping fields
      add :shipping_name, :string

      # Notes
      add :seller_notes, :string
      add :customer_notes, :string
    end
  end

  def down do
    alter table(:universal_orders) do
      remove :fulfillment_status
      remove :shipped_at
      remove :shipping_status
      remove :tracking_number
      remove :carrier
      remove :estimated_delivery
      remove :delivered_at
      remove :shipping_name
      remove :seller_notes
      remove :customer_notes
    end
  end
end