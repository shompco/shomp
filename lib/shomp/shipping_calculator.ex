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
    # Filter to only physical products
    physical_items = Enum.filter(items, fn item ->
      is_map(item) && Map.get(item, :type) == "physical"
    end)

    if Enum.empty?(physical_items) do
      {:ok, []}
    else
      # Use default store address if not provided
      store_address = store_address || default_store_address()

      # Calculate combined package dimensions and weight
      package = calculate_package_dimensions(physical_items)

      # Get shipping rates from Shippo
      case ShippoApi.calculate_rates(store_address, shipping_address, package) do
        {:ok, rates} ->
          {:ok, format_shipping_options(rates)}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Calculate shipping for a single product.
  """
  def calculate_product_shipping(product, shipping_address, store_address \\ nil) do
    # Digital products don't need shipping
    if product.type == "digital" do
      {:ok, []}
    else
      items = [%{
        type: product.type,
        quantity: 1,
        weight: convert_to_float(Map.get(product, :weight, 1.0)),
        length: convert_to_float(Map.get(product, :length, 6.0)),
        width: convert_to_float(Map.get(product, :width, 4.0)),
        height: convert_to_float(Map.get(product, :height, 2.0))
      }]

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
    %{
      name: "Shomp Store",
      street1: "123 Main St",
      city: "San Francisco",
      state: "CA",
      zip: "94105",
      country: "US"
    }
  end
end
