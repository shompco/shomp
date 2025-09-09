defmodule Shomp.UniversalOrders.UniversalOrder do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User
  alias Shomp.UniversalOrders.UniversalOrderItem

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :id

  schema "universal_orders" do
    field :universal_order_id, :string
    field :stripe_payment_intent_id, :string
    field :total_amount, :decimal
    field :platform_fee_amount, :decimal
    field :status, :string, default: "pending"
    field :payment_status, :string, default: "pending"
    
    # Customer information
    field :customer_email, :string
    field :customer_name, :string
    
    # Shipping address fields (for physical products)
    field :shipping_address_line1, :string
    field :shipping_address_line2, :string
    field :shipping_address_city, :string
    field :shipping_address_state, :string
    field :shipping_address_postal_code, :string
    field :shipping_address_country, :string
    
    belongs_to :user, User
    belongs_to :billing_address, Shomp.Addresses.Address
    belongs_to :shipping_address, Shomp.Addresses.Address
    
    has_many :universal_order_items, UniversalOrderItem
    has_many :payment_splits, Shomp.PaymentSplits.PaymentSplit, foreign_key: :universal_order_id, references: :universal_order_id
    has_many :refunds, Shomp.Refunds.Refund, foreign_key: :universal_order_id, references: :universal_order_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(universal_order, attrs) do
    universal_order
    |> cast(attrs, [:universal_order_id, :user_id, :stripe_payment_intent_id, :total_amount, :platform_fee_amount, :status, :payment_status, :billing_address_id, :shipping_address_id, :customer_email, :customer_name, :shipping_address_line1, :shipping_address_line2, :shipping_address_city, :shipping_address_state, :shipping_address_postal_code, :shipping_address_country])
    |> validate_required([:universal_order_id, :user_id, :stripe_payment_intent_id, :total_amount, :customer_email, :customer_name])
    |> validate_format(:customer_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    |> validate_length(:customer_name, min: 2, max: 100)
    |> validate_inclusion(:status, ["pending", "processing", "completed", "cancelled"])
    |> validate_inclusion(:payment_status, ["pending", "paid", "failed", "refunded", "partially_refunded"])
    |> unique_constraint(:universal_order_id)
    |> unique_constraint(:stripe_payment_intent_id)
    |> foreign_key_constraint(:user_id)
  end

  def create_changeset(universal_order, attrs) do
    universal_order
    |> changeset(attrs)
    |> put_change(:universal_order_id, generate_universal_order_id())
    |> put_change(:status, "pending")
    |> put_change(:payment_status, "pending")
  end

  defp generate_universal_order_id do
    date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false)
    "UO_#{date}_#{random}"
  end
end
