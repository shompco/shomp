defmodule ShompWeb.PageController do
  use ShompWeb, :controller
  alias Shomp.Products
  alias Shomp.Categories

  def home(conn, _params) do
    latest_products = Products.get_latest_products(8)
    featured_products = Products.get_featured_products(2)
    categories_with_products = Categories.get_categories_with_products()
    render(conn, :home,
      latest_products: latest_products,
      featured_products: featured_products,
      categories_with_products: categories_with_products
    )
  end


end
