defmodule Shomp.Orders.OrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Orders.Order
  alias Shomp.Products.Product

  schema "order_items" do
    field :quantity, :integer, default: 1
    field :price, :decimal
    
    belongs_to :order, Order
    belongs_to :product, Product

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating order items.
  """
  def create_changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:quantity, :price, :order_id, :product_id])
    |> validate_required([:quantity, :price, :order_id, :product_id])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:product_id)
  end
end
