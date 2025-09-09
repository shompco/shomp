defmodule Shomp.PaymentSplits.PaymentSplit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "payment_splits" do
    field :payment_split_id, :string
    field :universal_order_id, :string
    field :stripe_payment_intent_id, :string
    field :store_id, :string
    field :stripe_account_id, :string
    field :store_amount, :decimal
    field :platform_fee_amount, :decimal
    field :total_amount, :decimal
    field :stripe_transfer_id, :string
    field :transfer_status, :string, default: "pending"
    field :refunded_amount, :decimal, default: Decimal.new(0)
    field :refund_status, :string, default: "none"
    field :is_escrow, :boolean, default: false
  field :stripe_fee_amount, :decimal, default: 0
  field :adjusted_store_amount, :decimal, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment_split, attrs) do
    payment_split
    |> cast(attrs, [:payment_split_id, :universal_order_id, :stripe_payment_intent_id, :store_id, :stripe_account_id, :store_amount, :platform_fee_amount, :total_amount, :stripe_transfer_id, :transfer_status, :refunded_amount, :refund_status, :is_escrow, :stripe_fee_amount, :adjusted_store_amount])
    |> validate_required([:payment_split_id, :universal_order_id, :stripe_payment_intent_id, :store_id, :store_amount, :total_amount])
    |> validate_inclusion(:transfer_status, ["pending", "succeeded", "failed", "escrow"])
    |> validate_inclusion(:refund_status, ["none", "partial", "full"])
    |> validate_number(:store_amount, greater_than_or_equal_to: 0)
    |> validate_number(:platform_fee_amount, greater_than_or_equal_to: 0)
    |> validate_number(:total_amount, greater_than: 0)
    |> validate_number(:stripe_fee_amount, greater_than_or_equal_to: 0)
    |> validate_number(:adjusted_store_amount, greater_than_or_equal_to: 0)
    |> validate_stripe_account_for_direct_transfers()
    |> unique_constraint(:payment_split_id)
  end

  def create_changeset(payment_split, attrs) do
    payment_split
    |> changeset(attrs)
    |> put_change(:payment_split_id, generate_payment_split_id())
    |> put_change(:transfer_status, "pending")
    |> put_change(:refund_status, "none")
  end

  def refund_changeset(payment_split, attrs) do
    payment_split
    |> cast(attrs, [:refunded_amount, :refund_status])
    |> validate_number(:refunded_amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:refund_status, ["none", "partial", "full"])
  end

  defp validate_stripe_account_for_direct_transfers(changeset) do
    is_escrow = get_field(changeset, :is_escrow)
    stripe_account_id = get_field(changeset, :stripe_account_id)
    
    if is_escrow == false && (is_nil(stripe_account_id) || stripe_account_id == "") do
      add_error(changeset, :stripe_account_id, "is required for direct transfers")
    else
      changeset
    end
  end

  defp generate_payment_split_id do
    date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false)
    "PS_#{date}_#{random}"
  end
end
