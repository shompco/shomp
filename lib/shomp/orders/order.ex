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

    # Enhanced order status fields
    field :fulfillment_status, :string, default: "unfulfilled"
    field :payment_status, :string, default: "pending"
    field :shipped_at, :utc_datetime

    # Physical goods tracking
    field :shipping_status, :string, default: "ordered"
    field :tracking_number, :string
    field :carrier, :string
    field :estimated_delivery, :date
    field :delivered_at, :utc_datetime

    # Shipping address
    field :shipping_name, :string
    field :shipping_address_line1, :string
    field :shipping_address_line2, :string
    field :shipping_city, :string
    field :shipping_state, :string
    field :shipping_postal_code, :string
    field :shipping_country, :string

    # Notes
    field :seller_notes, :string
    field :customer_notes, :string

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
    |> cast(attrs, [:immutable_id, :total_amount, :stripe_session_id, :user_id, :fulfillment_status, :payment_status, :shipping_status, :tracking_number, :carrier, :estimated_delivery, :delivered_at, :shipping_name, :shipping_address_line1, :shipping_address_line2, :shipping_city, :shipping_state, :shipping_postal_code, :shipping_country, :seller_notes, :customer_notes])
    |> validate_required([:immutable_id, :total_amount, :stripe_session_id, :user_id])
    |> validate_number(:total_amount, greater_than: 0)
    |> validate_inclusion(:status, ["pending", "processing", "completed", "cancelled"])
    |> validate_inclusion(:fulfillment_status, ["unfulfilled", "partially_fulfilled", "fulfilled"])
    |> validate_inclusion(:payment_status, ["pending", "paid", "failed", "refunded", "partially_refunded"])
    |> validate_inclusion(:shipping_status, ["ordered", "label_printed", "shipped", "delivered"])
    |> validate_length(:tracking_number, max: 100)
    |> validate_length(:carrier, max: 50)
    |> validate_length(:seller_notes, max: 1000)
    |> validate_length(:customer_notes, max: 1000)
    |> unique_constraint(:immutable_id)
    |> unique_constraint(:stripe_session_id)
    |> foreign_key_constraint(:user_id)
    |> put_change(:status, "pending")
    |> put_change(:fulfillment_status, "unfulfilled")
    |> put_change(:payment_status, "pending")
    |> put_change(:shipping_status, "ordered")
  end

  @doc """
  A changeset for updating orders.
  """
  def update_changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :total_amount, :fulfillment_status, :payment_status, :shipped_at, :shipping_status, :tracking_number, :carrier, :estimated_delivery, :delivered_at, :shipping_name, :shipping_address_line1, :shipping_address_line2, :shipping_city, :shipping_state, :shipping_postal_code, :shipping_country, :seller_notes, :customer_notes])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "cancelled"])
    |> validate_inclusion(:fulfillment_status, ["unfulfilled", "partially_fulfilled", "fulfilled"])
    |> validate_inclusion(:payment_status, ["pending", "paid", "failed", "refunded", "partially_refunded"])
    |> validate_inclusion(:shipping_status, ["ordered", "label_printed", "shipped", "delivered"])
    |> validate_number(:total_amount, greater_than: 0)
    |> validate_length(:tracking_number, max: 100)
    |> validate_length(:carrier, max: 50)
    |> validate_length(:seller_notes, max: 1000)
    |> validate_length(:customer_notes, max: 1000)
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
