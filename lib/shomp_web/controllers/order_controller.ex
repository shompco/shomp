defmodule ShompWeb.OrderController do
  use ShompWeb, :controller

  alias Shomp.Orders

  def show(conn, %{"id" => order_id}) do
    case Orders.get_order_by_immutable_id!(order_id) do
      nil ->
        conn
        |> put_flash(:error, "Order not found.")
        |> redirect(to: ~p"/purchases")

      order ->
        # Preload order items and products
        order_with_details = Shomp.Repo.preload(order, [
          order_items: :product,
          user: []
        ])

        # Manually fetch store data for each product
        order_with_stores = %{order_with_details | 
          order_items: Enum.map(order_with_details.order_items, fn order_item ->
            store = Shomp.Stores.get_store_by_store_id(order_item.product.store_id)
            %{order_item | product: %{order_item.product | store: store}}
          end)
        }

        conn
        |> assign(:order, order_with_stores)
        |> assign(:page_title, "Order #{order.immutable_id}")
        |> assign(:get_download_token, &get_download_token/2)
        |> render(:show)
    end
  end

  defp get_download_token(product_id, user_id) do
    case Shomp.Downloads.get_download_by_product_and_user(product_id, user_id) do
      nil -> nil
      download -> download.token
    end
  end

  def index(conn, _params) do
    user_id = conn.assigns.current_scope.user.id
    
    # Get all user orders with products loaded
    orders = Orders.list_user_orders(user_id)
    |> Shomp.Repo.preload([order_items: :product])

    # Manually fetch store data for each product
    orders_with_stores = Enum.map(orders, fn order ->
      order_items_with_stores = Enum.map(order.order_items, fn order_item ->
        store = Shomp.Stores.get_store_by_store_id(order_item.product.store_id)
        %{order_item | product: %{order_item.product | store: store}}
      end)
      %{order | order_items: order_items_with_stores}
    end)

    conn
    |> assign(:orders, orders_with_stores)
    |> assign(:page_title, "My Orders")
    |> render(:index)
  end
end
