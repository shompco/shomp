defmodule ShompWeb.OrderController do
  use ShompWeb, :controller

  alias Shomp.Orders

  def show(conn, %{"id" => order_id}) do
    show_order(conn, order_id)
  end

  def show(conn, %{"immutable_id" => order_id}) do
    show_order(conn, order_id)
  end

  defp show_order(conn, order_id) do
    case Orders.get_order_by_immutable_id!(order_id) do
      nil ->
        # Check if user is admin, if so redirect to admin view
        if conn.assigns.current_scope.user.role == "admin" do
          conn
          |> put_flash(:error, "Order not found in user orders. Redirecting to admin view.")
          |> redirect(to: ~p"/admin/orders/#{order_id}")
        else
          conn
          |> put_flash(:error, "Order not found.")
          |> redirect(to: ~p"/purchases")
        end

      order ->
        # Preload order items and products
        order_with_details = Shomp.Repo.preload(order, [
          order_items: :product,
          user: []
        ])

        # Manually fetch store data and categories for each product
        order_with_stores = %{order_with_details | 
          order_items: Enum.map(order_with_details.order_items, fn order_item ->
            store = Shomp.Stores.get_store_by_store_id(order_item.product.store_id)
            
            # Load platform category if it exists
            product_with_store = %{order_item.product | store: store}
            product_with_categories = if product_with_store.category_id do
              case Shomp.Repo.get(Shomp.Categories.Category, product_with_store.category_id) do
                nil -> product_with_store
                category -> %{product_with_store | category: category}
              end
            else
              product_with_store
            end
            
            # Load custom category if it exists
            product_with_all = if product_with_categories.custom_category_id do
              case Shomp.Repo.get(Shomp.Categories.Category, product_with_categories.custom_category_id) do
                nil -> product_with_categories
                custom_category -> %{product_with_categories | custom_category: custom_category}
              end
            else
              product_with_categories
            end
            
            %{order_item | product: product_with_all}
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

    # Manually fetch store data and categories for each product
    orders_with_stores = Enum.map(orders, fn order ->
      order_items_with_stores = Enum.map(order.order_items, fn order_item ->
        store = Shomp.Stores.get_store_by_store_id(order_item.product.store_id)
        
        # Load platform category if it exists
        product_with_store = %{order_item.product | store: store}
        product_with_categories = if product_with_store.category_id do
          case Shomp.Repo.get(Shomp.Categories.Category, product_with_store.category_id) do
            nil -> product_with_store
            category -> %{product_with_store | category: category}
          end
        else
          product_with_store
        end
        
        # Load custom category if it exists
        product_with_all = if product_with_categories.custom_category_id do
          case Shomp.Repo.get(Shomp.Categories.Category, product_with_categories.custom_category_id) do
            nil -> product_with_categories
            custom_category -> %{product_with_categories | custom_category: custom_category}
          end
        else
          product_with_categories
        end
        
        %{order_item | product: product_with_all}
      end)
      %{order | order_items: order_items_with_stores}
    end)

    conn
    |> assign(:orders, orders_with_stores)
    |> assign(:page_title, "My Orders")
    |> render(:index)
  end
end
