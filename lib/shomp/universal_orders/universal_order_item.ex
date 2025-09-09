defmodule Shomp.UniversalOrders.UniversalOrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Products.Product

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "universal_order_items" do
    field :order_item_id, :string
    field :universal_order_id, :string
    field :store_id, :string
    field :quantity, :integer, default: 1
    field :unit_price, :decimal
    field :total_price, :decimal
    field :store_amount, :decimal
    field :platform_fee_amount, :decimal
    field :payment_split_id, :string
    
    belongs_to :product, Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(universal_order_item, attrs) do
    universal_order_item
    |> cast(attrs, [:order_item_id, :universal_order_id, :product_id, :store_id, :quantity, :unit_price, :total_price, :store_amount, :platform_fee_amount, :payment_split_id])
    |> validate_required([:order_item_id, :universal_order_id, :product_id, :store_id, :quantity, :unit_price, :total_price, :store_amount])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than: 0)
    |> validate_number(:total_price, greater_than: 0)
    |> validate_number(:store_amount, greater_than_or_equal_to: 0)
    |> unique_constraint(:order_item_id)
    |> foreign_key_constraint(:product_id)
  end

  def create_changeset(universal_order_item, attrs) do
    universal_order_item
    |> changeset(attrs)
    |> put_change(:order_item_id, generate_order_item_id())
  end

  defp generate_order_item_id do
    date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false)
    "OI_#{date}_#{random}"
  end
end
