defmodule Shomp.Payments do
  @moduledoc """
  The Payments context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Payments.Payment
  alias Shomp.Products

  @doc """
  Creates a Stripe checkout session for a product.
  """
  def create_checkout_session(product_id, user_id, success_url, cancel_url) do
    with {:ok, product} <- get_product_with_user(product_id, user_id),
         {:ok, _synced_product} <- ensure_product_has_stripe_id(product),
         {:ok, session} <- create_stripe_session(product, success_url, cancel_url),
         {:ok, payment} <- create_payment_record(product, user_id, session.id) do
      {:ok, session, payment}
    end
  end

  @doc """
  Handles Stripe webhook events.
  """
  def handle_webhook(event) do
    case event.type do
      "checkout.session.completed" ->
        handle_checkout_completed(event.data.object)

      "payment_intent.succeeded" ->
        handle_payment_succeeded(event.data.object)

      "payment_intent.payment_failed" ->
        handle_payment_failed(event.data.object)

      _ ->
        {:ok, :ignored}
    end
  end

  @doc """
  Gets a payment by Stripe payment ID.
  """
  def get_payment_by_stripe_id(stripe_payment_id) do
    Repo.get_by(Payment, stripe_payment_id: stripe_payment_id)
  end

  @doc """
  Updates a payment status.
  """
  def update_payment_status(payment, status) do
    payment
    |> Payment.changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Creates a payment record.
  """
  def create_payment(attrs \\ %{}) do
    %Payment{}
    |> Payment.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a payment with product and user associations.
  """
  def get_payment!(id) do
    Payment
    |> Repo.get!(id)
    |> Repo.preload([:product, :user])
  end

  @doc """
  Lists payments for a user.
  """
  def list_user_payments(user_id) do
    Payment
    |> where(user_id: ^user_id)
    |> preload([:product])
    |> Repo.all()
  end

  # Private functions

  defp get_product_with_user(product_id, _user_id) do
    case Products.get_product!(product_id) do
      nil -> {:error, :product_not_found}
      product -> {:ok, product}
    end
  end

  defp ensure_product_has_stripe_id(product) do
    if product.stripe_product_id do
      {:ok, product}
    else
      # Try to sync the product with Stripe
      Products.sync_product_with_stripe(product)
    end
  end

  defp create_stripe_session(product, success_url, cancel_url) do
    # Create a price for the product if it doesn't exist
    case create_or_get_stripe_price(product) do
      {:ok, price} ->
        Stripe.Session.create(%{
          payment_method_types: ["card"],
          line_items: [
            %{
              price: price.id,
              quantity: 1
            }
          ],
          mode: "payment",
          success_url: success_url,
          cancel_url: cancel_url,
          metadata: %{
            product_id: product.id,
            product_type: product.type
          }
        })
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_or_get_stripe_price(product) do
    # Check if we already have a price for this product
    if product.stripe_product_id do
      # Look for existing price
      case Stripe.Price.list(%{product: product.stripe_product_id, active: true}) do
        %{data: [price | _]} ->
          {:ok, price}
        
        _ ->
          # Create new price
          Stripe.Price.create(%{
            product: product.stripe_product_id,
            unit_amount: trunc(product.price * 100), # Convert to cents
            currency: "usd",
            active: true
          })
      end
    else
      {:error, :no_stripe_product}
    end
  end

  defp create_payment_record(product, user_id, session_id) do
    create_payment(%{
      amount: product.price,
      stripe_payment_id: session_id,
      product_id: product.id,
      user_id: user_id
    })
  end

  defp handle_checkout_completed(session) do
    case get_payment_by_stripe_id(session.id) do
      nil -> {:error, :payment_not_found}
      payment -> update_payment_status(payment, "succeeded")
    end
  end

  defp handle_payment_succeeded(_payment_intent) do
    # Handle successful payment intent
    {:ok, :payment_succeeded}
  end

  defp handle_payment_failed(_payment_intent) do
    # Handle failed payment intent
    {:ok, :payment_failed}
  end
end
