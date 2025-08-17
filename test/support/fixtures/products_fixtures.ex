defmodule Shomp.ProductsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Shomp.Products` context.
  """

  import Shomp.StoresFixtures

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    store = attrs[:store] || store_fixture()

    attrs =
      Enum.into(attrs, %{
        title: "some product title",
        description: "some product description",
        price: "99.99",
        type: "digital",
        file_path: "/path/to/file.pdf",
        store_id: store.id
      })

    {:ok, product} = Shomp.Products.create_product(attrs)
    product
  end
end
