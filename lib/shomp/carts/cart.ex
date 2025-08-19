defmodule Shomp.Carts.Cart do
  use Ecto.Schema
  import Ecto.Changeset

  schema "carts" do
    field :status, :string, default: "active" # active, abandoned, completed
    field :total_amount, :decimal, default: Decimal.new(0)
    
    belongs_to :user, Shomp.Accounts.User
    belongs_to :store, Shomp.Stores.Store
    has_many :cart_items, Shomp.Carts.CartItem
    
    timestamps()
  end

  @doc false
  def changeset(cart, attrs) do
    cart
    |> cast(attrs, [:status, :total_amount, :user_id, :store_id])
    |> validate_required([:user_id, :store_id])
    |> validate_inclusion(:status, ["active", "abandoned", "completed"])
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:store_id)
  end

  @doc """
  Creates a changeset for a new cart.
  """
  def create_changeset(cart, attrs) do
    cart
    |> changeset(attrs)
    |> put_change(:status, "active")
    |> put_change(:total_amount, Decimal.new(0))
  end

  @doc """
  Updates the cart total amount based on cart items.
  """
  def update_total_changeset(cart, total_amount) do
    cart
    |> change(%{total_amount: total_amount})
  end

  @doc """
  Checks if the cart is active and can be modified.
  """
  def active?(cart) do
    cart.status == "active"
  end

  @doc """
  Checks if the cart has any items.
  """
  def has_items?(cart) do
    length(cart.cart_items || []) > 0
  end

  @doc """
  Gets the total number of items in the cart.
  """
  def item_count(cart) do
    (cart.cart_items || [])
    |> Enum.reduce(0, fn item, acc -> acc + item.quantity end)
  end
end
