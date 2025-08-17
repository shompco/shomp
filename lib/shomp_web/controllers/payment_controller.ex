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

    case verify_webhook_signature(payload, signature) do
      {:ok, event} ->
        Payments.handle_webhook(event)
        json(conn, %{received: true})

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid webhook signature"})
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

  # Private functions

  defp verify_webhook_signature(payload, [signature]) do
    webhook_secret = Application.get_env(:shomp, :stripe_webhook_secret)
    Stripe.Webhook.construct_event(payload, signature, webhook_secret)
  end

  defp verify_webhook_signature(_payload, _signature) do
    {:error, :missing_signature}
  end
end
