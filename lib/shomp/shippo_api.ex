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

    Logger.info("=== SHIPPO API CALCULATE RATES ===")
    Logger.info("API Key configured: #{if api_key && api_key != "", do: "YES", else: "NO"}")
    Logger.info("API Key length: #{if api_key, do: String.length(api_key), else: "nil"}")
    Logger.info("From address: #{inspect(from_address)}")
    Logger.info("To address: #{inspect(to_address)}")
    Logger.info("Parcel: #{inspect(parcel)}")
    Logger.info("Options: #{inspect(opts)}")

    if is_nil(api_key) or api_key == "" do
      Logger.error("Shippo API key not configured")
      {:error, :api_key_not_configured}
    else
      request_body = build_rate_request(from_address, to_address, parcel, opts)
      Logger.info("Shippo API request body: #{inspect(request_body)}")

      case make_request("/shipments", request_body, api_key) do
        {:ok, %{"rates" => rates}} when is_list(rates) and length(rates) > 0 ->
          Logger.info("Shippo API success - received #{length(rates)} rates")
          Logger.info("Raw rates: #{inspect(rates)}")
          formatted_rates = format_rates(rates)
          Logger.info("Formatted rates: #{inspect(formatted_rates)}")
          {:ok, formatted_rates}
        {:ok, %{"rates" => []} = response} ->
          Logger.warning("Shippo API returned no shipping rates - trying with common carriers")
          Logger.info("Full response: #{inspect(response)}")

          # Try again with common carriers
          request_with_carriers = Map.put(request_body, "carrier_accounts", ["usps", "ups", "fedex"])
          Logger.info("Retrying with carriers: #{inspect(request_with_carriers)}")

          case make_request("/shipments", request_with_carriers, api_key) do
            {:ok, %{"rates" => rates}} when is_list(rates) and length(rates) > 0 ->
              Logger.info("Shippo API success with carriers - received #{length(rates)} rates")
              formatted_rates = format_rates(rates)
              {:ok, formatted_rates}
            {:ok, %{"rates" => []}} ->
              Logger.warning("Still no rates even with carriers")
              {:ok, []}
            {:error, reason} ->
              Logger.error("Retry with carriers failed: #{inspect(reason)}")
              {:ok, []}
          end
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
      "name" => Map.get(address, :name) || Map.get(address, "name") || "",
      "street1" => Map.get(address, :street1) || Map.get(address, "street1") || "",
      "city" => Map.get(address, :city) || Map.get(address, "city") || "",
      "state" => Map.get(address, :state) || Map.get(address, "state") || "",
      "zip" => Map.get(address, :zip) || Map.get(address, "zip") || "",
      "country" => Map.get(address, :country) || Map.get(address, "country") || "US"
    }
  end

  defp format_parcel(parcel) do
    # Ensure minimum realistic dimensions for Shippo
    # Convert Decimal values to floats for JSON encoding
    length_raw = Map.get(parcel, :length) || Map.get(parcel, "length") || 6.0
    width_raw = Map.get(parcel, :width) || Map.get(parcel, "width") || 4.0
    height_raw = Map.get(parcel, :height) || Map.get(parcel, "height") || 2.0
    weight_raw = Map.get(parcel, :weight) || Map.get(parcel, "weight") || 1.0

    # Convert to float if it's a Decimal
    length = case length_raw do
      %Decimal{} = d -> Decimal.to_float(d)
      n when is_number(n) -> n
      _ -> 6.0
    end

    width = case width_raw do
      %Decimal{} = d -> Decimal.to_float(d)
      n when is_number(n) -> n
      _ -> 4.0
    end

    height = case height_raw do
      %Decimal{} = d -> Decimal.to_float(d)
      n when is_number(n) -> n
      _ -> 2.0
    end

    weight = case weight_raw do
      %Decimal{} = d -> Decimal.to_float(d)
      n when is_number(n) -> n
      _ -> 1.0
    end

    %{
      "length" => max(length, 1.0),
      "width" => max(width, 1.0),
      "height" => max(height, 1.0),
      "weight" => max(weight, 0.1),
      "mass_unit" => Map.get(parcel, :weight_unit) || Map.get(parcel, "weight_unit") || "lb",
      "distance_unit" => Map.get(parcel, :distance_unit) || Map.get(parcel, "distance_unit") || "in"
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
    # Filter to only show the most common/useful shipping options
    useful_services = [
      "usps_priority", "usps_ground", "usps_express",
      "ups_ground", "ups_standard", "ups_next_day_air",
      "fedex_ground", "fedex_2_day", "fedex_standard_overnight"
    ]

    rates
    |> Enum.map(fn rate ->
      %{
        id: rate["object_id"],
        object_id: rate["object_id"],
        name: rate["servicelevel"]["name"],
        service_name: rate["servicelevel"]["name"],
        service_token: rate["servicelevel"]["token"],
        carrier: rate["provider"],
        cost: rate["amount"],
        amount: rate["amount"],
        currency: rate["currency"],
        estimated_days: rate["estimated_days"],
        duration_terms: rate["duration_terms"]
      }
    end)
    |> Enum.filter(fn rate ->
      # Only show useful services or if no useful services found, show first 5 cheapest
      rate.service_token in useful_services
    end)
    |> Enum.sort_by(& &1.amount)
    |> Enum.take(5)  # Limit to 5 options max
  end

  defp make_request(endpoint, body, api_key) do
    url = "#{@base_url}#{endpoint}"

    Logger.info("=== SHIPPO API HTTP REQUEST ===")
    Logger.info("URL: #{url}")
    Logger.info("Body: #{inspect(body)}")
    Logger.info("API Key (first 10 chars): #{String.slice(api_key, 0, 10)}...")
    Logger.info("Headers: #{inspect(%{
      "Authorization" => "ShippoToken #{String.slice(api_key, 0, 10)}...",
      "Content-Type" => "application/json",
      "Shippo-API-Version" => @api_version
    })}")

    case Req.post(url,
      json: body,
      headers: %{
        "Authorization" => "ShippoToken #{api_key}",
        "Content-Type" => "application/json",
        "Shippo-API-Version" => @api_version
      }
    ) do
      {:ok, %{status: status_code, body: response_body}} when status_code in 200..299 ->
        Logger.info("Shippo API success - Status: #{status_code}")
        Logger.info("Response body: #{inspect(response_body)}")
        {:ok, response_body}
      {:ok, %{status: status_code, body: response_body}} ->
        Logger.error("Shippo API error: #{status_code} - #{inspect(response_body)}")
        {:error, :api_error}
      {:error, reason} ->
        Logger.error("Shippo API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate a shipping label for a shipment.

  ## Parameters
  - `from_address`: Map with sender address details
  - `to_address`: Map with recipient address details
  - `parcel`: Map with package details
  - `service_token`: Service level token (e.g., "ups_ground", "fedex_ground")
  - `carrier_account`: Carrier account ID (optional)

  ## Returns
  - `{:ok, label_data}` - Success with label information
  - `{:error, reason}` - Error with reason
  """
  def generate_label(from_address, to_address, parcel, service_token, carrier_account \\ nil) do
    require Logger

    Logger.info("=== SHIPPO LABEL GENERATION ===")
    Logger.info("From address: #{inspect(from_address)}")
    Logger.info("To address: #{inspect(to_address)}")
    Logger.info("Parcel: #{inspect(parcel)}")
    Logger.info("Service token: #{service_token}")
    Logger.info("Carrier account: #{inspect(carrier_account)}")

    api_key = Application.get_env(:shomp, :shippo_api_key)

    if is_nil(api_key) or api_key == "" do
      Logger.error("Shippo API key not configured")
      {:error, :api_key_missing}
    else
      # Step 1: Create shipment to get rates
      shipment_url = "#{@base_url}/shipments"

      shipment_body = %{
        "address_from" => format_address(from_address),
        "address_to" => format_address(to_address),
        "parcels" => [format_parcel(parcel)],
        "async" => false
      }

      Logger.info("Step 1 - Creating shipment...")
      Logger.info("Shipment URL: #{shipment_url}")
      Logger.info("Shipment body: #{inspect(shipment_body)}")

      case Req.post(shipment_url,
        json: shipment_body,
        headers: %{
          "Authorization" => "ShippoToken #{api_key}",
          "Content-Type" => "application/json",
          "Shippo-API-Version" => @api_version
        }
      ) do
        {:ok, %{status: status_code, body: shipment_response}} when status_code in 200..299 ->
          IO.puts("=== SHIPMENT CREATED SUCCESSFULLY ===")
          IO.puts("Status: #{status_code}")

          # Step 2: Find the rate with the matching service token
          rates = Map.get(shipment_response, "rates", [])
          IO.puts("Available rates: #{length(rates)}")

          matching_rate = Enum.find(rates, fn rate ->
            rate_service_token = get_in(rate, ["servicelevel", "token"])
            IO.puts("Checking rate: #{rate_service_token} vs #{service_token}")
            rate_service_token == service_token
          end)

          if matching_rate do
            IO.puts("=== FOUND MATCHING RATE ===")
            IO.puts("Rate ID: #{matching_rate["object_id"]}")
            IO.puts("Rate Amount: #{matching_rate["amount"]}")

            # Step 3: Purchase the rate to generate the label
            transaction_url = "#{@base_url}/transactions"

            transaction_body = %{
              "rate" => matching_rate["object_id"],
              "async" => false
            }

            IO.puts("Step 3 - Purchasing rate to generate label...")
            IO.puts("Transaction URL: #{transaction_url}")
            IO.puts("Transaction body: #{inspect(transaction_body)}")

            case Req.post(transaction_url,
              json: transaction_body,
              headers: %{
                "Authorization" => "ShippoToken #{api_key}",
                "Content-Type" => "application/json",
                "Shippo-API-Version" => @api_version
              }
            ) do
              {:ok, %{status: trans_status, body: transaction_response}} when trans_status in 200..299 ->
                IO.puts("=== TRANSACTION SUCCESS ===")
                IO.puts("Transaction Status: #{trans_status}")
                IO.puts("Transaction Response: #{inspect(transaction_response)}")

                # Extract label URL from transaction response
                label_url = get_in(transaction_response, ["label_url"]) ||
                           get_in(transaction_response, ["commercial_invoice_url"])

                tracking_number = get_in(transaction_response, ["tracking_number"])

                IO.puts("Final label_url: #{inspect(label_url)}")
                IO.puts("Final tracking_number: #{inspect(tracking_number)}")

                {:ok, %{
                  label_url: label_url,
                  tracking_number: tracking_number,
                  transaction: transaction_response,
                  shipment: shipment_response
                }}

              {:ok, %{status: trans_status, body: transaction_response}} ->
                IO.puts("=== TRANSACTION ERROR ===")
                IO.puts("Status: #{trans_status}")
                IO.puts("Response: #{inspect(transaction_response)}")
                {:error, :transaction_failed}

              {:error, reason} ->
                IO.puts("=== TRANSACTION REQUEST FAILED ===")
                IO.puts("Error: #{inspect(reason)}")
                {:error, reason}
            end
          else
            IO.puts("=== NO MATCHING RATE FOUND ===")
            IO.puts("Requested service token: #{service_token}")
            IO.puts("Available service tokens:")
            Enum.each(rates, fn rate ->
              token = get_in(rate, ["servicelevel", "token"])
              IO.puts("  - #{token}")
            end)
            {:error, :rate_not_found}
          end

        {:ok, %{status: status_code, body: response_body}} ->
          Logger.error("Shippo label generation error: #{status_code} - #{inspect(response_body)}")
          {:error, :api_error}

        {:error, reason} ->
          Logger.error("Shippo label generation request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
