defmodule Shomp.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Products.Product
  alias Shomp.Accounts.User

  schema "payments" do
    field :amount, :decimal
    field :stripe_payment_id, :string
    field :status, :string, default: "pending"
    belongs_to :product, Product
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  A payment changeset for creation and updates.
  """
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:amount, :stripe_payment_id, :product_id, :user_id, :status])
    |> validate_required([:amount, :stripe_payment_id, :product_id, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:status, ["pending", "succeeded", "failed", "canceled"])
    |> unique_constraint(:stripe_payment_id)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  A payment changeset for creation.
  """
  def create_changeset(payment, attrs) do
    payment
    |> changeset(attrs)
    |> put_change(:status, "pending")
  end
end
