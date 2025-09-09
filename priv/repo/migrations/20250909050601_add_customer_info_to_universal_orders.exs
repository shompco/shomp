defmodule Shomp.Repo.Migrations.AddCustomerInfoToUniversalOrders do
  use Ecto.Migration

  def change do
    alter table(:universal_orders) do
      # Customer information
      add :customer_email, :string, null: false
      add :customer_name, :string, null: false
      
      # Shipping address fields (for physical products)
      add :shipping_address_line1, :string
      add :shipping_address_line2, :string
      add :shipping_address_city, :string
      add :shipping_address_state, :string
      add :shipping_address_postal_code, :string
      add :shipping_address_country, :string
    end

    create index(:universal_orders, [:customer_email])
    create index(:universal_orders, [:shipping_address_country])
  end
end