defmodule ShompWeb.PageController do
  use ShompWeb, :controller
  alias Shomp.Products

  def home(conn, _params) do
    latest_products = Products.get_latest_products(8)
    featured_products = Products.get_featured_products(2)
    render(conn, :home, latest_products: latest_products, featured_products: featured_products)
  end


end
