defmodule Shomp.UniversalOrders do
  @moduledoc """
  The UniversalOrders context for managing multi-store orders.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.UniversalOrders.{UniversalOrder, UniversalOrderItem}
  alias Shomp.Stores.StoreKYCContext
  alias Shomp.Stores

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
  Gets a universal order by ID.
  """
  def get_universal_order!(id) do
    Repo.get!(UniversalOrder, id)
    |> Repo.preload([:universal_order_items, :payment_splits, :refunds, :user, :billing_address, :shipping_address])
  end

  @doc """
  Lists universal orders by store ID.
  """
  def list_universal_orders_by_store(store_id) do
    UniversalOrder
    |> where([u], u.store_id == ^store_id)
    |> order_by([u], [desc: u.inserted_at])
    |> Repo.all()
    |> Repo.preload([:universal_order_items, :payment_splits, :user])
  end

  @doc """
  Updates universal order status.
  """
  def update_universal_order_status(universal_order, status) do
    universal_order
    |> UniversalOrder.changeset(%{status: status})
    |> Repo.update()
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
    orders = UniversalOrder
    |> apply_filters(filters)
    |> order_by([u], [desc: u.inserted_at])
    |> Repo.all()
    |> Repo.preload([:universal_order_items, :payment_splits, :user])

    # Enrich orders with merchant information
    Enum.map(orders, fn order ->
      # Get merchant info from payment splits
      merchant_info = if length(order.payment_splits) > 0 do
        first_split = List.first(order.payment_splits)
        store_kyc = Shomp.Stores.StoreKYCContext.get_kyc_by_store_id(first_split.store_id)

        if store_kyc do
          # Get the store to access user email
          store = Shomp.Stores.get_store_by_store_id(first_split.store_id)
          merchant_email = if store do
            user = Shomp.Accounts.get_user!(store.user_id)
            user.email
          else
            nil
          end

          %{
            stripe_account_id: store_kyc.stripe_account_id,
            merchant_email: merchant_email
          }
        else
          %{stripe_account_id: nil, merchant_email: nil}
        end
      else
        %{stripe_account_id: nil, merchant_email: nil}
      end

      Map.merge(order, merchant_info)
    end)
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
