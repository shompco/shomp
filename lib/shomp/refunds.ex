defmodule Shomp.Refunds do
  @moduledoc """
  The Refunds context for managing refunds with store attribution.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Refunds.Refund
  alias Shomp.PaymentSplits

  @doc """
  Creates a refund.
  """
  def create_refund(attrs \\ %{}) do
    %Refund{}
    |> Refund.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets refunds by universal order ID.
  """
  def get_refunds_by_universal_order(universal_order_id) do
    Refund
    |> where([r], r.universal_order_id == ^universal_order_id)
    |> order_by([r], [desc: r.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets refunds by store.
  """
  def get_refunds_by_store(store_id) do
    Refund
    |> where([r], r.store_id == ^store_id)
    |> order_by([r], [desc: r.inserted_at])
    |> Repo.all()
  end

  @doc """
  Lists all refunds with optional filters.
  """
  def list_all_refunds(filters \\ %{}) do
    Refund
    |> apply_filters(filters)
    |> order_by([r], [desc: r.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a refund by refund_id.
  """
  def get_refund_by_id(refund_id) do
    Repo.get_by(Refund, refund_id: refund_id)
  end

  @doc """
  Processes a refund.
  """
  def process_refund(refund_id, admin_user_id) do
    refund = Repo.get_by(Refund, refund_id: refund_id)
    
    # Update payment split refund amounts
    PaymentSplits.update_split_refund_amount(refund.payment_split_id, refund.refund_amount)
    
    # Update refund status
    refund
    |> Refund.process_changeset(%{
      status: "succeeded",
      processed_at: DateTime.utc_now(),
      processed_by_user_id: admin_user_id
    })
    |> Repo.update()
  end

  @doc """
  Updates a refund.
  """
  def update_refund(refund, attrs) do
    refund
    |> Refund.changeset(attrs)
    |> Repo.update()
  end

  # Private functions

  defp apply_filters(query, %{status: status}), do: where(query, [r], r.status == ^status)
  defp apply_filters(query, %{store_id: store_id}), do: where(query, [r], r.store_id == ^store_id)
  defp apply_filters(query, %{universal_order_id: order_id}), do: where(query, [r], r.universal_order_id == ^order_id)
  defp apply_filters(query, %{refund_type: type}), do: where(query, [r], r.refund_type == ^type)
  defp apply_filters(query, %{date_from: date}), do: where(query, [r], r.inserted_at >= ^date)
  defp apply_filters(query, %{date_to: date}), do: where(query, [r], r.inserted_at <= ^date)
  defp apply_filters(query, _), do: query
end
