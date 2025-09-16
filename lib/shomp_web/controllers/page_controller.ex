defmodule ShompWeb.PageController do
  use ShompWeb, :controller
  alias Shomp.Categories


  def home(conn, _params) do
    # Load categories with products and thumbnails for the categories section
    categories_with_products = Categories.get_categories_with_products_and_thumbnails()

    # Keep the original categories data for the dropdown
    categories_for_dropdown = Categories.get_categories_with_products()

    render(conn, :home,
      categories: categories_with_products,
      categories_with_products: categories_for_dropdown,
      page_title: "Sell Anything Online — Free"
    )
  end


end
