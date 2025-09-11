defmodule ShompWeb.PaymentController do
  use ShompWeb, :controller

  alias Shomp.Payments

  @doc """
  Creates a Stripe checkout session for a product.
  """
  def create_checkout(conn, %{"product_id" => product_id}) do
    user = conn.assigns.current_scope.user

    success_url = url(conn, ~p"/payments/success?session_id={CHECKOUT_SESSION_ID}")
    cancel_url = url(conn, ~p"/payments/cancel")

    case Payments.create_checkout_session(product_id, user.id, success_url, cancel_url) do
      {:ok, session, _payment} ->
        json(conn, %{session_id: session.id, url: session.url})

      {:error, :product_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Product not found"})

      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create checkout session"})
    end
  end

  @doc """
  Handles Stripe webhook events.
  """
  def webhook(conn, _params) do
    signature = get_req_header(conn, "stripe-signature")
    payload = conn.assigns.raw_body

    # Debug logging
    IO.puts("=== WEBHOOK DEBUG ===")
    IO.puts("Signature: #{inspect(signature)}")
    IO.puts("Raw body length: #{if payload, do: byte_size(payload), else: "nil"}")
    IO.puts("Raw body preview: #{if payload, do: String.slice(payload, 0, 100), else: "nil"}")

    case verify_webhook_signature(payload, signature) do
      {:ok, event} ->
        IO.puts("Webhook signature verified successfully")
        IO.puts("Event type: #{event.type}")

        try do
          result = Payments.handle_webhook(event)
          IO.puts("Webhook handling result: #{inspect(result)}")
          json(conn, %{received: true})
        rescue
          e ->
            IO.puts("ERROR: Exception during webhook handling: #{inspect(e)}")
            IO.puts("Stacktrace: #{inspect(__STACKTRACE__)}")
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Webhook processing failed", details: inspect(e)})
        end

      {:error, reason} ->
        IO.puts("Webhook signature verification failed: #{inspect(reason)}")
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid webhook signature", details: inspect(reason)})
    end
  end

  @doc """
  Shows payment success page.
  """
  def success(conn, %{"session_id" => session_id}) do
    render(conn, :success, session_id: session_id)
  end

  @doc """
  Shows payment cancel page.
  """
  def cancel(conn, _params) do
    render(conn, :cancel)
  end

  @doc """
  Creates a custom amount donation checkout session and redirects directly to Stripe.
  """
  def custom_donate(conn, %{"amount" => amount} = params) do
    # Parse the amount and create checkout session
    amount_int = case Integer.parse(amount) do
      {amount, _} when amount > 0 -> amount
      _ -> 25  # Default to $25 if invalid
    end

    # Get frequency from params, default to "one_time"
    frequency = Map.get(params, "frequency", "one_time")

    case Payments.create_donation_session(
      amount_int,
      frequency,
      "shomp",
      url(conn, ~p"/payments/success?session_id={CHECKOUT_SESSION_ID}&source=donation"),
      url(conn, ~p"/payments/cancel?source=donation")
    ) do
      {:ok, session} ->
        redirect(conn, external: session.url)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to create donation session. Please try again.")
        |> redirect(to: ~p"/donations")
    end
  end

  def custom_donate(conn, _params) do
    # Get the referer to determine where user came from
    referer = get_req_header(conn, "referer") |> List.first()
    back_page = get_back_page_name(referer)

    # Show a simple form to collect the amount
    render(conn, :custom_donate_form, back_page: back_page)
  end

  defp get_back_page_name(nil), do: "Home"
  defp get_back_page_name(referer) do
    cond do
      String.contains?(referer, "/about") -> "About"
      String.contains?(referer, "/requests") -> "Feature Requests"
      String.contains?(referer, "/stores") -> "Browse Stores"
      String.contains?(referer, "/donations") -> "Donations"
      String.contains?(referer, "/landing") -> "About Shomp"
      String.contains?(referer, "/") -> "Home"
      true -> "Home"
    end
  end


  # Private functions

  defp verify_webhook_signature(payload, [signature]) do
    webhook_secret = Application.get_env(:shomp, :stripe_webhook_secret)
    IO.puts("Webhook secret from config: #{inspect(webhook_secret)}")
    IO.puts("Environment STRIPE_WEBHOOK_SECRET: #{inspect(System.get_env("STRIPE_WEBHOOK_SECRET"))}")

    case webhook_secret do
      nil ->
        {:error, :missing_webhook_secret}
      secret ->
        Stripe.Webhook.construct_event(payload, signature, secret)
    end
  end

  defp verify_webhook_signature(_payload, _signature) do
    {:error, :missing_signature}
  end
end
