defmodule ShompWeb.ShippingController do
  use ShompWeb, :controller

  alias Shomp.Products
  alias Shomp.ShippingCalculator

  def calculate(conn, %{"product_id" => product_id, "shipping_address" => shipping_address}) do
    require Logger

    Logger.info("=== SHIPPING API CALCULATE ===")
    Logger.info("Product ID: #{product_id}")
    Logger.info("Shipping address: #{inspect(shipping_address)}")

    # Get product
    product = Products.get_product_with_store!(product_id)

    # Get store address for shipping calculation
    # Use store's ZIP code for shipping calculation
    store_address = case product.store.shipping_zip_code do
      nil -> %{
        "name" => product.store.name,
        "street1" => "123 Main St",
        "city" => "San Francisco",
        "state" => "CA",
        "zip" => "94105",
        "country" => "US"
      }
      zip_code ->
        base_address = Shomp.ZipCodeLookup.create_address_from_zip(zip_code)
        Map.merge(base_address, %{
          "name" => product.store.name,
          "street1" => "123 Main St"
        })
    end

    Logger.info("Using store address: #{inspect(store_address)}")

    # Calculate shipping
    case ShippingCalculator.calculate_product_shipping(product, shipping_address, store_address) do
      {:ok, shipping_options} ->
        Logger.info("Shipping calculation successful!")
        Logger.info("Shipping options: #{inspect(shipping_options)}")

        json(conn, %{
          success: true,
          shipping_options: shipping_options
        })

      {:error, reason} ->
        Logger.error("Shipping calculation failed: #{inspect(reason)}")

        json(conn, %{
          success: false,
          error: "Failed to calculate shipping rates"
        })
    end
  end

  def calculate(conn, _params) do
    json(conn, %{
      success: false,
      error: "Missing required fields: product_id, shipping_address"
    })
  end
end
