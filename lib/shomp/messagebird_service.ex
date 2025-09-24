defmodule Shomp.MessageBirdService do
  @moduledoc """
  Service for sending SMS messages via MessageBird.
  """

  require Logger

  @base_url "https://rest.messagebird.com"

  @doc """
  Sends an SMS via MessageBird API.
  """
  def send_sms(to_phone, message, opts \\ []) do
    api_key = System.get_env("MESSAGEBIRD_API_KEY")
    originator = System.get_env("MESSAGEBIRD_ORIGINATOR") || "Shomp"

    if is_nil(api_key) do
      Logger.warning("MESSAGEBIRD_API_KEY not configured, skipping SMS to #{to_phone}")
      {:ok, :skipped_no_api_key}
    else
      send_sms_with_key(to_phone, message, api_key, originator, opts)
    end
  end

  defp send_sms_with_key(to_phone, message, api_key, originator, opts) do
    # Clean phone number (remove non-digits except +)
    clean_phone = String.replace(to_phone, ~r/[^\d+]/, "")

    # Ensure phone number starts with country code
    formatted_phone = if String.starts_with?(clean_phone, "+") do
      clean_phone
    else
      # Assume US number if no country code
      "+1#{clean_phone}"
    end

    payload = %{
      originator: originator,
      recipients: formatted_phone,
      body: message
    }

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "AccessKey #{api_key}"}
    ]

    case Finch.build(:post, "#{@base_url}/messages", headers, Jason.encode!(payload)) |> Finch.request(Shomp.Finch) do
      {:ok, %Finch.Response{status: 201, body: body}} ->
        Logger.info("SMS sent successfully to #{formatted_phone}")
        {:ok, Jason.decode!(body)}

      {:ok, %Finch.Response{status: status_code, body: body}} ->
        Logger.error("Failed to send SMS to #{formatted_phone}. Status: #{status_code}, Body: #{body}")
        {:error, {:http_error, status_code, body}}

      {:error, reason} ->
        Logger.error("Failed to send SMS to #{formatted_phone}. Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validates a phone number format.
  """
  def validate_phone_number(phone_number) do
    # Basic phone number validation
    clean_phone = String.replace(phone_number, ~r/[^\d+]/, "")

    cond do
      String.length(clean_phone) < 10 ->
        {:error, "Phone number too short"}

      String.length(clean_phone) > 15 ->
        {:error, "Phone number too long"}

      String.match?(clean_phone, ~r/^\+\d+$/) ->
        {:ok, clean_phone}

      String.match?(clean_phone, ~r/^\d+$/) ->
        {:ok, "+1#{clean_phone}"}  # Assume US number

      true ->
        {:error, "Invalid phone number format"}
    end
  end
end
