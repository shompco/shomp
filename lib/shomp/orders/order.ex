defmodule Shomp.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User
  alias Shomp.Orders.OrderItem

  schema "orders" do
    field :immutable_id, :string
    field :total_amount, :decimal
    field :status, :string, default: "pending"
    field :stripe_session_id, :string
    
    belongs_to :user, User
    has_many :order_items, OrderItem
    has_many :products, through: [:order_items, :product]

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating orders.
  """
  def create_changeset(order, attrs) do
    order
    |> cast(attrs, [:immutable_id, :total_amount, :stripe_session_id, :user_id])
    |> validate_required([:immutable_id, :total_amount, :stripe_session_id, :user_id])
    |> validate_number(:total_amount, greater_than: 0)
    |> validate_inclusion(:status, ["pending", "processing", "completed", "cancelled"])
    |> unique_constraint(:immutable_id)
    |> unique_constraint(:stripe_session_id)
    |> foreign_key_constraint(:user_id)
    |> put_change(:status, "pending")
  end

  @doc """
  A changeset for updating orders.
  """
  def update_changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :total_amount])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "cancelled"])
    |> validate_number(:total_amount, greater_than: 0)
  end

  @doc """
  A changeset for updating order status.
  """
  def status_changeset(order, status) do
    order
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "cancelled"])
  end
end
