defmodule ShompWeb.PageController do
  use ShompWeb, :controller
  alias Shomp.Products
  alias Shomp.Categories


  def home(conn, _params) do
    # Load categories with products and thumbnails for the categories section
    categories_with_products = Categories.get_categories_with_products_and_thumbnails()

    # Load stores with products for the stores section
    stores = Shomp.Stores.list_stores_with_users()
    stores_with_products = Enum.map(stores, fn store ->
      products = Products.list_products_by_store(store.store_id)
      Map.put(store, :products, products)
    end)

    # Keep the original categories data for the dropdown
    categories_for_dropdown = Categories.get_categories_with_products()

    render(conn, :home,
      categories: categories_with_products,
      stores: stores_with_products,
      categories_with_products: categories_for_dropdown
    )
  end

end
