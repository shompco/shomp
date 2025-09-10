defmodule ShompWeb.PageController do
  use ShompWeb, :controller
  alias Shomp.Products
  alias Shomp.Categories

  def home(conn, _params) do
    latest_products = Products.get_latest_products(8)
    featured_products = Products.get_featured_products(2)
    categories_with_products = Categories.get_categories_with_products()

    # Add product counts to categories
    categories_with_counts = Enum.map(categories_with_products, fn {name, slug} ->
      category = Categories.get_category_by_slug!(slug)
      count = Products.count_products_by_category(category.id)
      {name, slug, count}
    end)

    render(conn, :home,
      latest_products: latest_products,
      featured_products: featured_products,
      categories_with_products: categories_with_products,
      categories_with_counts: categories_with_counts
    )
  end

end
