defmodule Shomp.BrevoService do
  @moduledoc """
  Service for sending emails via Brevo (formerly Sendinblue).
  """

  require Logger

  @base_url "https://api.brevo.com/v3"

  @doc """
  Sends an email via Brevo API.
  """
  def send_email(to_email, subject, message, opts \\ []) do
    api_key = System.get_env("BREVO_LIVE_KEY")

    if is_nil(api_key) do
      Logger.warning("BREVO_LIVE_KEY not configured, skipping email to #{to_email}")
      {:ok, :skipped_no_api_key}
    else
      send_email_with_key(to_email, subject, message, api_key, opts)
    end
  end

  defp send_email_with_key(to_email, subject, message, api_key, opts) do
    from_email = opts[:from_email] || "noreply@shomp.co"
    from_name = opts[:from_name] || "Shomp"

    payload = %{
      sender: %{
        email: from_email,
        name: from_name
      },
      to: [
        %{
          email: to_email
        }
      ],
      subject: subject,
      htmlContent: format_html_message(message),
      textContent: message
    }

    headers = [
      {"Content-Type", "application/json"},
      {"api-key", api_key}
    ]

    case Req.post("#{@base_url}/smtp/email",
                  json: payload,
                  headers: headers) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        Logger.info("Email sent successfully to #{to_email}")
        {:ok, body}

      {:ok, %Req.Response{status: status_code, body: body}} ->
        Logger.error("Failed to send email to #{to_email}. Status: #{status_code}, Body: #{inspect(body)}")
        {:error, {:http_error, status_code, body}}

      {:error, reason} ->
        Logger.error("Failed to send email to #{to_email}. Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp format_html_message(message) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Shomp Notification</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 20px;
          border-radius: 8px 8px 0 0;
          text-align: center;
        }
        .content {
          background: #f8f9fa;
          padding: 30px;
          border-radius: 0 0 8px 8px;
          border: 1px solid #e9ecef;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #6c757d;
          font-size: 14px;
        }
        a {
          color: #667eea;
          text-decoration: none;
        }
        a:hover {
          text-decoration: underline;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🔔 Shomp Notification</h1>
      </div>
      <div class="content">
        #{String.replace(message, "\n", "<br>")}
      </div>
      <div class="footer">
        <p>This email was sent from <a href="https://shomp.co">Shomp</a></p>
        <p>If you no longer wish to receive these notifications, you can update your preferences in your account settings.</p>
      </div>
    </body>
    </html>
    """
  end
end
