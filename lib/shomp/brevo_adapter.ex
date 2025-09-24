defmodule Shomp.BrevoAdapter do
  @moduledoc """
  Custom Brevo API adapter for Swoosh.
  """

  @behaviour Swoosh.Adapter

  require Logger

  @base_url "https://api.brevo.com/v3"

  def deliver(email, config) do
    api_key = config[:api_key] || System.get_env("BREVO_LIVE_KEY")

    if is_nil(api_key) do
      Logger.error("Brevo API key not configured")
      {:error, :no_api_key}
    else
      send_email_via_api(email, api_key)
    end
  end

  defp send_email_via_api(email, api_key) do
    payload = build_payload(email)

    headers = [
      {"Content-Type", "application/json"},
      {"api-key", api_key}
    ]

    case Req.post("#{@base_url}/smtp/email",
                  json: payload,
                  headers: headers) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        Logger.info("Email sent successfully via Brevo API")
        {:ok, body}

      {:ok, %Req.Response{status: status_code, body: body}} ->
        Logger.error("Failed to send email via Brevo API. Status: #{status_code}, Body: #{inspect(body)}")
        {:error, {:http_error, status_code, body}}

      {:error, reason} ->
        Logger.error("Failed to send email via Brevo API. Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_payload(email) do
    %{
      sender: %{
        email: extract_from_email(email),
        name: extract_from_name(email)
      },
      to: build_recipients(email.to),
      subject: email.subject,
      htmlContent: email.html_body || format_text_as_html(email.text_body),
      textContent: email.text_body
    }
  end

  defp extract_from_email(email) do
    case email.from do
      {_name, email} -> email
      email when is_binary(email) -> email
      _ -> "noreply@shomp.co"
    end
  end

  defp extract_from_name(email) do
    case email.from do
      {name, _email} -> name
      _ -> "Shomp"
    end
  end

  defp build_recipients(recipients) when is_list(recipients) do
    Enum.map(recipients, fn
      {_name, email} -> %{email: email}
      email when is_binary(email) -> %{email: email}
    end)
  end

  defp build_recipients(recipient) do
    build_recipients([recipient])
  end

  defp format_text_as_html(text) when is_binary(text) do
    text
    |> String.replace("\n", "<br>")
    |> String.replace(" ", "&nbsp;")
  end

  defp format_text_as_html(_), do: ""
end
