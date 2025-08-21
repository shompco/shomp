defmodule Shomp.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Orders.{Order, OrderItem}

  @doc """
  Returns the list of orders.
  """
  def list_orders do
    Repo.all(Order)
  end

  @doc """
  Gets a single order.
  """
  def get_order!(id), do: Repo.get!(Order, id)

  @doc """
  Gets a single order by immutable_id.
  """
  def get_order_by_immutable_id!(immutable_id), do: Repo.get_by!(Order, immutable_id: immutable_id)

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
    order
    |> Order.status_changeset(status)
    |> Repo.update()
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
