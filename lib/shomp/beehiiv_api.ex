defmodule Shomp.BeehiivApi do
  @moduledoc """
  Beehiiv API client for newsletter management.
  """

  require Logger

  @base_url "https://api.beehiiv.com/v2"
  @timeout 30_000

  @doc """
  Subscribes an email to the Beehiiv newsletter.

  ## Examples

      iex> subscribe_to_newsletter("user@example.com")
      {:ok, %{id: "subscriber_id", email: "user@example.com"}}

      iex> subscribe_to_newsletter("invalid-email")
      {:error, "Invalid email format"}

  """
  def subscribe_to_newsletter(email, opts \\ []) do
    publication_id = get_publication_id()
    api_key = get_api_key()

    if !publication_id || !api_key do
      Logger.warning("Beehiiv API credentials not configured")
      {:error, "API credentials not configured"}
    else
      url = "#{@base_url}/publications/#{publication_id}/subscribers"

      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]

      body = %{
        email: email,
        send_welcome_email: Keyword.get(opts, :send_welcome_email, true)
      }

      case Req.post(url, json: body, headers: headers, receive_timeout: @timeout) do
        {:ok, %{status: 201, body: data}} ->
          Logger.info("Successfully subscribed #{email} to Beehiiv newsletter")
          {:ok, data}

        {:ok, %{status: 400, body: %{"errors" => errors}}} ->
          error_message = extract_error_message(errors)
          Logger.warning("Beehiiv API error for #{email}: #{error_message}")
          {:error, error_message}

        {:ok, %{status: 400, body: _}} ->
          Logger.warning("Beehiiv API error for #{email}: Invalid request")
          {:error, "Invalid request"}

        {:ok, %{status: 409, body: _}} ->
          Logger.info("Email #{email} already subscribed to Beehiiv newsletter")
          {:ok, %{email: email, status: "already_subscribed"}}

        {:ok, %{status: status_code, body: response_body}} ->
          Logger.error("Beehiiv API error for #{email}: HTTP #{status_code} - #{inspect(response_body)}")
          {:error, "API error: HTTP #{status_code}"}

        {:error, %{reason: reason}} ->
          Logger.error("Beehiiv API request failed for #{email}: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Unsubscribes an email from the Beehiiv newsletter.

  ## Examples

      iex> unsubscribe_from_newsletter("user@example.com")
      {:ok, %{email: "user@example.com", status: "unsubscribed"}}

  """
  def unsubscribe_from_newsletter(email) do
    publication_id = get_publication_id()
    api_key = get_api_key()

    if !publication_id || !api_key do
      Logger.warning("Beehiiv API credentials not configured")
      {:error, "API credentials not configured"}
    else
      # First, get the subscriber ID
      case get_subscriber_by_email(email) do
        {:ok, %{"id" => subscriber_id}} ->
          unsubscribe_by_id(subscriber_id, email)
        {:error, :not_found} ->
          Logger.info("Email #{email} not found in Beehiiv newsletter")
          {:ok, %{email: email, status: "not_found"}}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Gets subscriber information by email.

  ## Examples

      iex> get_subscriber_by_email("user@example.com")
      {:ok, %{"id" => "subscriber_id", "email" => "user@example.com"}}

  """
  def get_subscriber_by_email(email) do
    publication_id = get_publication_id()
    api_key = get_api_key()

    if !publication_id || !api_key do
      Logger.warning("Beehiiv API credentials not configured")
      {:error, "API credentials not configured"}
    else
      url = "#{@base_url}/publications/#{publication_id}/subscribers"

      headers = [
        {"Authorization", "Bearer #{api_key}"}
      ]

      params = [email: email]
      url_with_params = url <> "?" <> URI.encode_query(params)

      case Req.get(url_with_params, headers: headers, receive_timeout: @timeout) do
        {:ok, %{status: 200, body: %{"data" => [subscriber | _]}}} ->
          {:ok, subscriber}

        {:ok, %{status: 200, body: %{"data" => []}}} ->
          {:error, :not_found}

        {:ok, %{status: 200, body: data}} ->
          Logger.error("Unexpected Beehiiv API response format: #{inspect(data)}")
          {:error, "Unexpected API response format"}

        {:ok, %{status: status_code, body: response_body}} ->
          Logger.error("Beehiiv API error: HTTP #{status_code} - #{inspect(response_body)}")
          {:error, "API error: HTTP #{status_code}"}

        {:error, %{reason: reason}} ->
          Logger.error("Beehiiv API request failed: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Gets publication information.

  ## Examples

      iex> get_publication()
      {:ok, %{"id" => "pub_id", "name" => "Newsletter Name"}}

  """
  def get_publication do
    publication_id = get_publication_id()
    api_key = get_api_key()

    if !publication_id || !api_key do
      Logger.warning("Beehiiv API credentials not configured")
      {:error, "API credentials not configured"}
    else
      url = "#{@base_url}/publications/#{publication_id}"

      headers = [
        {"Authorization", "Bearer #{api_key}"}
      ]

      case Req.get(url, headers: headers, receive_timeout: @timeout) do
        {:ok, %{status: 200, body: data}} ->
          {:ok, data}

        {:ok, %{status: status_code, body: response_body}} ->
          Logger.error("Beehiiv API error: HTTP #{status_code} - #{inspect(response_body)}")
          {:error, "API error: HTTP #{status_code}"}

        {:error, %{reason: reason}} ->
          Logger.error("Beehiiv API request failed: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  # Private functions

  defp unsubscribe_by_id(subscriber_id, email) do
    publication_id = get_publication_id()
    api_key = get_api_key()

    url = "#{@base_url}/publications/#{publication_id}/subscribers/#{subscriber_id}"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body = %{status: "unsubscribed"}

    case Req.patch(url, json: body, headers: headers, receive_timeout: @timeout) do
        {:ok, %{status: 200, body: data}} ->
          Logger.info("Successfully unsubscribed #{email} from Beehiiv newsletter")
          {:ok, data}

        {:ok, %{status: status_code, body: response_body}} ->
          Logger.error("Beehiiv API error for unsubscribe #{email}: HTTP #{status_code} - #{inspect(response_body)}")
          {:error, "API error: HTTP #{status_code}"}

        {:error, %{reason: reason}} ->
          Logger.error("Beehiiv API unsubscribe request failed for #{email}: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
  end

  defp get_api_key do
    Application.get_env(:shomp, :beehiiv_api_key)
  end

  defp get_publication_id do
    Application.get_env(:shomp, :beehiiv_publication_id)
  end

  defp extract_error_message(errors) when is_list(errors) do
    errors
    |> Enum.map(fn error ->
      case error do
        %{"message" => message} -> message
        %{"field" => field, "message" => message} -> "#{field}: #{message}"
        _ -> inspect(error)
      end
    end)
    |> Enum.join(", ")
  end

  defp extract_error_message(error) when is_map(error) do
    case error do
      %{"message" => message} -> message
      _ -> inspect(error)
    end
  end

  defp extract_error_message(error) do
    inspect(error)
  end
end
