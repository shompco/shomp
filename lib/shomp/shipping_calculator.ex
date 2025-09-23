defmodule Shomp.ShippingCalculator do
  @moduledoc """
  Shipping cost calculator for physical products.
  """

  alias Shomp.ShippoApi

  @doc """
  Calculate shipping costs for a product or cart.

  ## Parameters
  - `items`: List of products with quantities
  - `shipping_address`: Map with shipping address details
  - `store_address`: Map with store address details (optional, defaults to US)

  ## Returns
  - `{:ok, shipping_options}` on success
  - `{:error, reason}` on failure
  """
  def calculate_shipping(items, shipping_address, store_address \\ nil) do
    require Logger

    Logger.info("=== SHIPPING CALCULATOR - CALCULATE SHIPPING ===")
    Logger.info("Items: #{inspect(items)}")
    Logger.info("Shipping address: #{inspect(shipping_address)}")
    Logger.info("Store address: #{inspect(store_address)}")

    # Filter to only physical products
    physical_items = Enum.filter(items, fn item ->
      is_map(item) && Map.get(item, :type) == "physical"
    end)

    Logger.info("Physical items: #{inspect(physical_items)}")

    if Enum.empty?(physical_items) do
      Logger.info("No physical items - returning empty rates")
      {:ok, []}
    else
      # Use default store address if not provided
      store_address = store_address || default_store_address()
      Logger.info("Using store address: #{inspect(store_address)}")

      # Calculate combined package dimensions and weight
      package = calculate_package_dimensions(physical_items)
      Logger.info("Calculated package: #{inspect(package)}")

      # Get shipping rates from Shippo
      Logger.info("Calling ShippoApi.calculate_rates...")
      case ShippoApi.calculate_rates(store_address, shipping_address, package) do
        {:ok, rates} ->
          Logger.info("ShippoApi returned rates: #{inspect(rates)}")
          formatted_options = format_shipping_options(rates)
          Logger.info("Formatted shipping options: #{inspect(formatted_options)}")
          {:ok, formatted_options}
        {:error, reason} ->
          Logger.error("ShippoApi error: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Calculate shipping for a single product.
  """
  def calculate_product_shipping(product, shipping_address, store_address \\ nil) do
    require Logger

    Logger.info("=== SHIPPING CALCULATOR - PRODUCT SHIPPING ===")
    Logger.info("Product type: #{product.type}")
    Logger.info("Product: #{inspect(product)}")
    Logger.info("Shipping address: #{inspect(shipping_address)}")
    Logger.info("Store address: #{inspect(store_address)}")

    # Digital products don't need shipping
    if product.type == "digital" do
      Logger.info("Digital product - no shipping needed")
      {:ok, []}
    else
      # Use provided store address or fallback to default
      store_address = store_address || default_store_address()

      Logger.info("Using store address: #{inspect(store_address)}")

      items = [%{
        type: product.type,
        quantity: 1,
        weight: convert_to_float(Map.get(product, :weight, 1.0)),
        length: convert_to_float(Map.get(product, :length, 6.0)),
        width: convert_to_float(Map.get(product, :width, 4.0)),
        height: convert_to_float(Map.get(product, :height, 2.0))
      }]

      Logger.info("Calculated items: #{inspect(items)}")
      calculate_shipping(items, shipping_address, store_address)
    end
  end

  @doc """
  Calculate shipping for a cart.
  """
  def calculate_cart_shipping(cart, shipping_address, store_address \\ nil) do
    # Filter out digital products and only calculate shipping for physical products
    physical_items = cart.cart_items
    |> Enum.filter(fn cart_item -> cart_item.product.type == "physical" end)
    |> Enum.map(fn cart_item ->
      %{
        type: cart_item.product.type,
        quantity: cart_item.quantity,
        weight: convert_to_float(Map.get(cart_item.product, :weight, 1.0)),
        length: convert_to_float(Map.get(cart_item.product, :length, 6.0)),
        width: convert_to_float(Map.get(cart_item.product, :width, 4.0)),
        height: convert_to_float(Map.get(cart_item.product, :height, 2.0))
      }
    end)

    if Enum.empty?(physical_items) do
      {:ok, []}
    else
      calculate_shipping(physical_items, shipping_address, store_address)
    end
  end

  defp calculate_package_dimensions(items) do
    # Simple calculation - sum weights and use largest dimensions
    total_weight = Enum.reduce(items, 0, fn item, acc ->
      weight = convert_to_float(Map.get(item, :weight, 1.0))
      acc + (weight * item.quantity)
    end)

    max_length = Enum.max_by(items, fn item ->
      convert_to_float(Map.get(item, :length, 6.0))
    end, fn -> 6.0 end) |> Map.get(:length, 6.0) |> convert_to_float()

    max_width = Enum.max_by(items, fn item ->
      convert_to_float(Map.get(item, :width, 4.0))
    end, fn -> 4.0 end) |> Map.get(:width, 4.0) |> convert_to_float()

    max_height = Enum.reduce(items, 0, fn item, acc ->
      height = convert_to_float(Map.get(item, :height, 2.0))
      acc + (height * item.quantity)
    end)

    %{
      weight: total_weight,
      length: max_length,
      width: max_width,
      height: max_height,
      weight_unit: "lb",
      distance_unit: "in"
    }
  end

  defp convert_to_float(value) do
    case value do
      %Decimal{} = decimal -> Decimal.to_float(decimal)
      float when is_float(float) -> float
      int when is_integer(int) -> int * 1.0
      _ -> 1.0
    end
  end

  defp format_shipping_options(rates) do
    rates
    |> Enum.map(fn rate ->
      %{
        id: rate.object_id,
        name: "#{rate.carrier} #{rate.service_name}",
        carrier: rate.carrier,
        service: rate.service_name,
        cost: rate.amount,
        currency: rate.currency,
        estimated_days: rate.estimated_days,
        duration_terms: rate.duration_terms
      }
    end)
    |> Enum.sort_by(& &1.cost)
  end

    defp default_store_address do
      # Use the actual store address from the product's store
      # This should be configurable per store
      %{
        name: "Shomp Store",
        street1: "123 Main St",
        city: "San Francisco",
        state: "CA",
        zip: "94105",
        country: "US"
      }
    end

    defp get_store_address_from_zip(zip_code) do
      # Create a minimal address from just the ZIP code
      # This is sufficient for Shippo API calculations
      base_address = Shomp.ZipCodeLookup.create_address_from_zip(zip_code)

      Map.merge(base_address, %{
        name: "Store",
        street1: "123 Main St"
      })
    end
end
