defmodule Shomp.Repo.Migrations.AddPhysicalGoodsTrackingToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      # Enhanced fulfillment status for physical goods
      add :shipping_status, :string, default: "not_shipped"
      add :tracking_number, :string
      add :carrier, :string
      add :estimated_delivery, :date
      add :delivered_at, :utc_datetime
      
      # Shipping address (for physical goods)
      add :shipping_name, :string
      add :shipping_address_line1, :string
      add :shipping_address_line2, :string
      add :shipping_city, :string
      add :shipping_state, :string
      add :shipping_postal_code, :string
      add :shipping_country, :string
      
      # Seller notes and customer communication
      add :seller_notes, :text
      add :customer_notes, :text
    end

    # Add indexes for better query performance
    create index(:orders, [:shipping_status])
    create index(:orders, [:tracking_number])
    create index(:orders, [:delivered_at])
  end
end