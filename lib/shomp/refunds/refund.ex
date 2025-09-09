defmodule Shomp.Refunds.Refund do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "refunds" do
    field :refund_id, :string
    field :universal_order_id, :string
    field :payment_split_id, :string
    field :store_id, :string
    field :stripe_refund_id, :string
    field :refund_amount, :decimal
    field :refund_reason, :string
    field :refund_type, :string
    field :status, :string, default: "pending"
    field :processed_at, :utc_datetime
    field :stripe_charge_id, :string
    field :admin_notes, :string
    
    belongs_to :processed_by_user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(refund, attrs) do
    refund
    |> cast(attrs, [:refund_id, :universal_order_id, :payment_split_id, :store_id, :stripe_refund_id, :refund_amount, :refund_reason, :refund_type, :status, :processed_at, :stripe_charge_id, :admin_notes, :processed_by_user_id])
    |> validate_required([:refund_id, :universal_order_id, :payment_split_id, :store_id, :stripe_refund_id, :refund_amount, :refund_reason, :refund_type])
    |> validate_inclusion(:refund_type, ["full", "partial", "item_specific"])
    |> validate_inclusion(:status, ["pending", "succeeded", "failed"])
    |> validate_number(:refund_amount, greater_than: 0)
    |> unique_constraint(:refund_id)
    |> unique_constraint(:stripe_refund_id)
    |> foreign_key_constraint(:processed_by_user_id)
  end

  def create_changeset(refund, attrs) do
    refund
    |> changeset(attrs)
    |> put_change(:refund_id, generate_refund_id())
    |> put_change(:status, "pending")
  end

  def process_changeset(refund, attrs) do
    refund
    |> cast(attrs, [:status, :processed_at, :processed_by_user_id])
    |> validate_inclusion(:status, ["succeeded", "failed"])
    |> validate_required([:status, :processed_at])
  end

  defp generate_refund_id do
    date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false)
    "RF_#{date}_#{random}"
  end
end
