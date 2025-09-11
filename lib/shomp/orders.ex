defmodule Shomp.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Orders.{Order, OrderItem}
  alias Shomp.Products.Product

  @doc """
  Returns the list of orders.
  """
  def list_orders do
    Repo.all(Order)
  end

  @doc """
  Gets a single order.
  """
  def get_order!(id) do
    Order
    |> Repo.get!(id)
    |> Repo.preload([:order_items, :products, :user])
  end

  @doc """
  Gets a single order by immutable_id.
  """
  def get_order_by_immutable_id!(immutable_id, preloads \\ []) do
    Order
    |> Repo.get_by!(immutable_id: immutable_id)
    |> Repo.preload(preloads)
  end

  @doc """
  Gets a single order by stripe session ID.
  """
  def get_order_by_stripe_session_id!(stripe_session_id), do: Repo.get_by!(Order, stripe_session_id: stripe_session_id)

  @doc """
  Creates an order.
  """
  def create_order(attrs \\ %{}) do
    %Order{}
    |> Order.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an order.
  """
  def update_order(%Order{} = order, attrs) do
    order
    |> Order.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates an order status.
  """
  def update_order_status(%Order{} = order, status) do
    case order
         |> Order.status_changeset(status)
         |> Repo.update() do
      {:ok, updated_order} ->
        # Broadcast the order update to all subscribers
        broadcast_order_update(updated_order)
        {:ok, updated_order}

      error -> error
    end
  end

  @doc """
  Updates an order with comprehensive changes (status, shipping, tracking, etc.).
  """
  def update_order_comprehensive(%Order{} = order, attrs) do
    case order
         |> Order.update_changeset(attrs)
         |> Repo.update() do
      {:ok, updated_order} ->
        # Broadcast the order update to all subscribers
        broadcast_order_update(updated_order)
        {:ok, updated_order}

      error -> error
    end
  end

  defp broadcast_order_update(order) do
    # Preload the order with all necessary associations
    order_with_preloads = order
    |> Repo.preload([:order_items, :products, :user])

    # Get all stores that have products in this order
    store_ids = order_with_preloads.order_items
    |> Enum.map(& &1.product.store_id)
    |> Enum.uniq()

    # Broadcast to each store's order channel
    Enum.each(store_ids, fn store_id ->
      Phoenix.PubSub.broadcast(Shomp.PubSub, "store_orders:#{store_id}", %{
        event: "order_updated",
        payload: order_with_preloads
      })
    end)
  end

  @doc """
  Deletes an order.
  """
  def delete_order(%Order{} = order) do
    Repo.delete(order)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking order changes.
  """
  def change_order(%Order{} = order, attrs \\ %{}) do
    Order.update_changeset(order, attrs)
  end

  @doc """
  Lists orders for a specific user.
  """
  def list_user_orders(user_id) do
    Order
    |> where(user_id: ^user_id)
    |> preload([:order_items, :products])
    |> order_by([o], [desc: o.inserted_at])
    |> Repo.all()
  end

  @doc """
  Lists orders for a specific store (orders containing products from that store).
  Takes the store's store_id (UUID string), not the database ID.
  """
  def list_store_orders(store_id) do
    Order
    |> join(:inner, [o], oi in OrderItem, on: o.id == oi.order_id)
    |> join(:inner, [o, oi], p in Product, on: oi.product_id == p.id)
    |> where([o, oi, p], p.store_id == ^store_id)
    |> preload([:order_items, :products, :user])
    |> order_by([o], [desc: o.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets orders for a specific user that contain a specific product.
  This is used to verify if a user can review a product.
  """
  def get_user_orders_with_product(user_id, product_id) do
    Order
    |> join(:inner, [o], oi in OrderItem, on: o.id == oi.order_id)
    |> where([o, oi], o.user_id == ^user_id and oi.product_id == ^product_id and o.status == "completed")
    |> preload([:order_items, :products])
    |> Repo.all()
  end

  @doc """
  Checks if a user has purchased a specific product.
  """
  def user_purchased_product?(user_id, product_id) do
    Order
    |> join(:inner, [o], oi in OrderItem, on: o.id == oi.order_id)
    |> where([o, oi], o.user_id == ^user_id and oi.product_id == ^product_id and o.status == "completed")
    |> select([o, oi], count(oi.id))
    |> Repo.one()
    |> case do
      count when count > 0 -> true
      _ -> false
    end
  end

  # OrderItem functions

  @doc """
  Creates an order item.
  """
  def create_order_item(attrs \\ %{}) do
    %OrderItem{}
    |> OrderItem.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists order items for an order.
  """
  def list_order_items(order_id) do
    OrderItem
    |> where(order_id: ^order_id)
    |> preload(:product)
    |> Repo.all()
  end

  @doc """
  Gets a single order item.
  """
  def get_order_item!(id), do: Repo.get!(OrderItem, id)

  @doc """
  Deletes an order item.
  """
  def delete_order_item(%OrderItem{} = order_item) do
    Repo.delete(order_item)
  end
end
