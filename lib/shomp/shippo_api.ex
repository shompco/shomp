defmodule Shomp.ShippoApi do
  @moduledoc """
  Shippo API client for calculating shipping rates.
  """

  require Logger

  @base_url "https://api.goshippo.com"
  @api_version "2018-02-08"

  @doc """
  Calculate shipping rates for a package.

  ## Parameters
  - `from_address`: Map with address details (street1, city, state, zip, country)
  - `to_address`: Map with address details (street1, city, state, zip, country)
  - `parcel`: Map with package details (length, width, height, weight, weight_unit)
  - `carriers`: List of carrier account IDs (optional)
  - `services`: List of service level tokens (optional)

  ## Returns
  - `{:ok, rates}` on success
  - `{:error, reason}` on failure
  """
  def calculate_rates(from_address, to_address, parcel, opts \\ []) do
    api_key = Application.get_env(:shomp, :shippo_api_key)

    if is_nil(api_key) or api_key == "" do
      Logger.error("Shippo API key not configured")
      {:error, :api_key_not_configured}
    else
      request_body = build_rate_request(from_address, to_address, parcel, opts)
      Logger.info("Shippo API request: #{inspect(request_body)}")

      case make_request("/shipments", request_body, api_key) do
        {:ok, %{"rates" => rates}} when is_list(rates) and length(rates) > 0 ->
          {:ok, format_rates(rates)}
        {:ok, %{"rates" => []} = response} ->
          Logger.warning("Shippo API returned no shipping rates")
          Logger.info("Full response: #{inspect(response)}")
          {:ok, []}
        {:ok, %{"error" => error}} ->
          Logger.error("Shippo API error: #{inspect(error)}")
          {:error, :api_error}
        {:ok, response} ->
          Logger.error("Unexpected Shippo API response: #{inspect(response)}")
          {:error, :api_error}
        {:error, reason} ->
          Logger.error("Shippo API request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Get available carriers for the account.
  """
  def get_carriers do
    api_key = Application.get_env(:shomp, :shippo_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, :api_key_not_configured}
    else
      case make_request("/carriers", %{}, api_key) do
        {:ok, carriers} ->
          {:ok, carriers}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_rate_request(from_address, to_address, parcel, opts) do
    %{
      "address_from" => format_address(from_address),
      "address_to" => format_address(to_address),
      "parcels" => [format_parcel(parcel)],
      "async" => false
    }
    |> maybe_add_carriers(opts[:carriers])
    |> maybe_add_services(opts[:services])
  end

  defp format_address(address) do
    %{
      "name" => address[:name] || "",
      "street1" => address[:street1] || "",
      "city" => address[:city] || "",
      "state" => address[:state] || "",
      "zip" => address[:zip] || "",
      "country" => address[:country] || "US"
    }
  end

  defp format_parcel(parcel) do
    %{
      "length" => parcel[:length] || 1.0,
      "width" => parcel[:width] || 1.0,
      "height" => parcel[:height] || 1.0,
      "weight" => parcel[:weight] || 1.0,
      "mass_unit" => parcel[:weight_unit] || "lb",
      "distance_unit" => parcel[:distance_unit] || "in"
    }
  end

  defp maybe_add_carriers(request, nil), do: request
  defp maybe_add_carriers(request, []), do: request
  defp maybe_add_carriers(request, carriers) do
    Map.put(request, "carrier_accounts", carriers)
  end

  defp maybe_add_services(request, nil), do: request
  defp maybe_add_services(request, []), do: request
  defp maybe_add_services(request, services) do
    Map.put(request, "servicelevels", services)
  end

  defp format_rates(rates) do
    rates
    |> Enum.map(fn rate ->
      %{
        object_id: rate["object_id"],
        service_name: rate["servicelevel"]["name"],
        service_token: rate["servicelevel"]["token"],
        carrier: rate["provider"],
        amount: rate["amount"],
        currency: rate["currency"],
        estimated_days: rate["estimated_days"],
        duration_terms: rate["duration_terms"]
      }
    end)
    |> Enum.sort_by(& &1.amount)
  end

  defp make_request(endpoint, body, api_key) do
    url = "#{@base_url}#{endpoint}"

    case Req.post(url,
      json: body,
      headers: %{
        "Authorization" => "ShippoToken #{api_key}",
        "Content-Type" => "application/json",
        "Shippo-API-Version" => @api_version
      }
    ) do
      {:ok, %{status: status_code, body: response_body}} when status_code in 200..299 ->
        {:ok, response_body}
      {:ok, %{status: status_code, body: response_body}} ->
        Logger.error("Shippo API error: #{status_code} - #{inspect(response_body)}")
        {:error, :api_error}
      {:error, reason} ->
        Logger.error("Shippo API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
