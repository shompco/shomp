defmodule Shomp.UniversalOrders do
  @moduledoc """
  The UniversalOrders context for managing multi-store orders.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.UniversalOrders.{UniversalOrder, UniversalOrderItem}

  @doc """
  Creates a universal order.
  """
  def create_universal_order(attrs \\ %{}) do
    %UniversalOrder{}
    |> UniversalOrder.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a universal order by universal_order_id.
  """
  def get_universal_order_by_id(universal_order_id) do
    Repo.get_by(UniversalOrder, universal_order_id: universal_order_id)
    |> Repo.preload([:universal_order_items, :payment_splits, :refunds, :user, :billing_address, :shipping_address])
  end

  @doc """
  Gets a universal order by Stripe payment intent ID.
  """
  def get_universal_order_by_payment_intent(payment_intent_id) do
    Repo.get_by(UniversalOrder, stripe_payment_intent_id: payment_intent_id)
    |> Repo.preload([:universal_order_items, :payment_splits, :refunds, :user, :billing_address, :shipping_address])
  end

  @doc """
  Lists universal orders with optional filters.
  """
  def list_universal_orders(filters \\ %{}) do
    UniversalOrder
    |> apply_filters(filters)
    |> order_by([u], [desc: u.inserted_at])
    |> Repo.all()
    |> Repo.preload([:universal_order_items, :payment_splits, :user])
  end

  @doc """
  Creates a universal order item.
  """
  def create_universal_order_item(attrs \\ %{}) do
    %UniversalOrderItem{}
    |> UniversalOrderItem.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a universal order.
  """
  def update_universal_order(universal_order, attrs) do
    universal_order
    |> UniversalOrder.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets universal orders by user.
  """
  def list_user_universal_orders(user_id) do
    UniversalOrder
    |> where([u], u.user_id == ^user_id)
    |> order_by([u], [desc: u.inserted_at])
    |> Repo.all()
    |> Repo.preload([:universal_order_items, :payment_splits])
  end

  # Private functions

  defp apply_filters(query, %{status: status}), do: where(query, [u], u.status == ^status)
  defp apply_filters(query, %{user_id: user_id}), do: where(query, [u], u.user_id == ^user_id)
  defp apply_filters(query, %{date_from: date}), do: where(query, [u], u.inserted_at >= ^date)
  defp apply_filters(query, %{date_to: date}), do: where(query, [u], u.inserted_at <= ^date)
  defp apply_filters(query, %{payment_status: status}), do: where(query, [u], u.payment_status == ^status)
  defp apply_filters(query, _), do: query
end
