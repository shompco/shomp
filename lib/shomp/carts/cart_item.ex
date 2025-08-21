defmodule Shomp.Carts.CartItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cart_items" do
    field :quantity, :integer, default: 1
    field :price, :decimal # Price at time of adding to cart
    
    belongs_to :cart, Shomp.Carts.Cart
    belongs_to :product, Shomp.Products.Product
    
    timestamps()
  end

  @doc false
  def changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:quantity, :price, :cart_id, :product_id])
    |> validate_required([:quantity, :price, :cart_id, :product_id])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
    |> foreign_key_constraint(:cart_id)
    |> foreign_key_constraint(:product_id)
  end

  @doc """
  Creates a changeset for a new cart item.
  """
  def create_changeset(cart_item, attrs) do
    cart_item
    |> changeset(attrs)
  end

  @doc """
  Updates the quantity of a cart item.
  """
  def update_quantity_changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:quantity])
    |> validate_required([:quantity])
    |> validate_number(:quantity, greater_than: 0)
  end

  @doc """
  Calculates the total price for this cart item.
  """
  def total_price(cart_item) do
    Decimal.mult(cart_item.price, cart_item.quantity)
  end

  @doc """
  Checks if the cart item has a valid quantity.
  """
  def valid_quantity?(cart_item) do
    cart_item.quantity > 0
  end
end
