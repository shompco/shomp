defmodule Shomp.PaymentSplits do
  @moduledoc """
  The PaymentSplits context for managing payment distributions.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.PaymentSplits.PaymentSplit

  @doc """
  Creates a payment split.
  """
  def create_payment_split(attrs \\ %{}) do
    %PaymentSplit{}
    |> PaymentSplit.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets payment splits by universal order ID.
  """
  def get_splits_by_universal_order(universal_order_id) do
    PaymentSplit
    |> where([p], p.universal_order_id == ^universal_order_id)
    |> Repo.all()
  end

  @doc """
  Lists payment splits by universal order ID (alias for get_splits_by_universal_order).
  """
  def list_payment_splits_by_universal_order(universal_order_id) do
    get_splits_by_universal_order(universal_order_id)
  end

  @doc """
  Gets a payment split by payment_split_id.
  """
  def get_payment_split_by_id(payment_split_id) do
    Repo.get_by(PaymentSplit, payment_split_id: payment_split_id)
  end

  @doc """
  Updates payment split refund amounts.
  """
  def update_split_refund_amount(split_id, refund_amount) do
    split = Repo.get_by(PaymentSplit, payment_split_id: split_id)
    
    new_refunded = Decimal.add(split.refunded_amount, refund_amount)
    refund_status = if Decimal.equal?(new_refunded, split.total_amount), do: "full", else: "partial"
    
    split
    |> PaymentSplit.refund_changeset(%{
      refunded_amount: new_refunded,
      refund_status: refund_status
    })
    |> Repo.update()
  end

  @doc """
  Lists payment splits with optional filters.
  """
  def list_payment_splits(filters \\ %{}) do
    PaymentSplit
    |> apply_filters(filters)
    |> order_by([p], [desc: p.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets payment splits by store.
  """
  def get_splits_by_store(store_id) do
    PaymentSplit
    |> where([p], p.store_id == ^store_id)
    |> Repo.all()
  end

  # Private functions

  @doc """
  Lists escrow payment splits (stores without KYC).
  """
  def list_escrow_payment_splits do
    Repo.all(from ps in PaymentSplit, where: ps.is_escrow == true)
  end

  @doc """
  Lists direct payment splits (stores with completed KYC).
  """
  def list_direct_payment_splits do
    Repo.all(from ps in PaymentSplit, where: ps.is_escrow == false)
  end

  @doc """
  Updates a payment split.
  """
  def update_payment_split(%PaymentSplit{} = payment_split, attrs) do
    payment_split
    |> PaymentSplit.changeset(attrs)
    |> Repo.update()
  end

  defp apply_filters(query, %{store_id: store_id}), do: where(query, [p], p.store_id == ^store_id)
  defp apply_filters(query, %{universal_order_id: order_id}), do: where(query, [p], p.universal_order_id == ^order_id)
  defp apply_filters(query, %{transfer_status: status}), do: where(query, [p], p.transfer_status == ^status)
  defp apply_filters(query, %{refund_status: status}), do: where(query, [p], p.refund_status == ^status)
  defp apply_filters(query, _), do: query
end
