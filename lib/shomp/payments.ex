defmodule Shomp.Payments do
  @moduledoc """
  The Payments context.
  """

  alias Phoenix.PubSub

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Payments.Payment
  alias Shomp.Products
  alias Shomp.Downloads
  alias Shomp.StripeConnect
  alias Shomp.UniversalOrders
  alias Shomp.PaymentSplits
  alias Shomp.Stores.StoreKYCContext
  alias Shomp.Notifications
  alias Shomp.Accounts
  alias Shomp.Stores

  @doc """
  Creates a Stripe checkout session for a donation.
  frequency: "one_time" | "monthly"
  """
  def create_donation_session(amount_dollars, frequency, store_slug, success_url, cancel_url) do
    unit_amount = amount_dollars * 100

    line_item =
      case frequency do
        "monthly" ->
          %{
            price_data: %{
              currency: "usd",
              product_data: %{
                name: "Donate to Shomp (Monthly)",
                description: "Recurring monthly donation"
              },
              recurring: %{interval: "month"},
              unit_amount: unit_amount
            },
            quantity: 1
          }

        _ ->
          %{
            price_data: %{
              currency: "usd",
              product_data: %{
                name: "Donate to Shomp (One-Time)",
                description: "One-time donation"
              },
              unit_amount: unit_amount
            },
            quantity: 1
          }
      end

    mode = if frequency == "monthly", do: "subscription", else: "payment"

    Stripe.Session.create(%{
      payment_method_types: ["card"],
      line_items: [line_item],
      mode: mode,
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: %{
        type: "donation",
        store_slug: store_slug,
        amount_dollars: amount_dollars,
        frequency: frequency
      }
    })
  end

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
  Creates a Stripe checkout session for an individual item with optional donation.
  """
  def create_individual_item_checkout_session(product, quantity, donate, user_id) do
    IO.puts("=== INDIVIDUAL ITEM CHECKOUT DEBUG ===")
    IO.puts("Product ID: #{product.id}")
    IO.puts("Quantity: #{quantity}")
    IO.puts("Donate: #{donate}")
    IO.puts("User ID: #{user_id}")

    with {:ok, _synced_product} <- ensure_product_has_stripe_id(product),
         {:ok, session} <- create_individual_item_stripe_session(product, quantity, donate, user_id) do
      IO.puts("Individual item checkout session created successfully: #{session.id}")
      IO.puts("Payment intent: #{session.payment_intent}")

      # Create payment record using the payment intent ID
      IO.puts("=== CREATING PAYMENT RECORD ===")
      IO.puts("Payment intent ID: #{session.payment_intent}")
      IO.puts("Product ID: #{product.id}")
      IO.puts("User ID: #{user_id}")
      IO.puts("Amount: #{product.price}")

      case create_payment(%{
        amount: product.price,
        stripe_payment_id: session.payment_intent,
        product_id: product.id,
        user_id: user_id,
        status: "pending"
      }) do
        {:ok, payment} ->
          IO.puts("✅ Payment record created successfully: #{payment.id}")
          IO.puts("✅ Payment stripe_payment_id: #{payment.stripe_payment_id}")
          {:ok, session}
        {:error, reason} ->
          IO.puts("❌ Failed to create payment record: #{inspect(reason)}")
          {:ok, session}  # Still return success even if payment record fails
      end
    else
      {:error, reason} ->
        IO.puts("Failed to create individual item checkout session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Creates a Stripe checkout session for a cart with multiple items.
  """
  def create_cart_checkout_session(cart_id, user_id) do
    alias Shomp.Carts

    IO.puts("=== PAYMENTS CHECKOUT DEBUG ===")
    IO.puts("Looking for cart_id: #{cart_id}, user_id: #{user_id}")

    # Find the cart by ID for the user
    all_carts = Carts.list_user_carts(user_id)
    IO.puts("User has #{length(all_carts)} carts")

    cart = all_carts |> Enum.find(&(&1.id == cart_id))
    IO.puts("Found cart: #{inspect(cart != nil)}")

    case cart do
      nil ->
        IO.puts("Cart not found!")
        {:error, :cart_not_found}

      cart ->
        IO.puts("Cart found, creating Stripe session...")
        case create_cart_stripe_session(cart, user_id) do
          {:ok, session} ->
            IO.puts("Stripe session created successfully")
            # Don't create payment records yet - let the webhook handle it after payment
            {:ok, session}

          {:error, reason} ->
            IO.puts("Failed to create Stripe session: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  @doc """
  Handles Stripe webhook events.
  """
  def handle_webhook(event) do
    case event.type do
      "checkout.session.completed" ->
        handle_checkout_completed(event.data.object)

      "charge.succeeded" ->
        handle_charge_succeeded(event.data.object)

      "payment_intent.charge_succeeded" ->
        handle_payment_intent_charge_succeeded(event.data.object)

      "payment_intent.succeeded" ->
        handle_payment_succeeded(event.data.object)

      "payment_intent.payment_failed" ->
        handle_payment_failed(event.data.object)

      "account.updated" ->
        handle_account_updated(event.data.object)

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
  Gets a payment by Stripe payment intent ID.
  """
  def get_payment_by_payment_intent_id(payment_intent_id) do
    Repo.get_by(Payment, stripe_payment_id: payment_intent_id)
  end

  @doc """
  Lists all payments by Stripe payment ID (for cart payments).
  """
  def list_payments_by_stripe_id(stripe_payment_id) do
    Payment
    |> where([p], p.stripe_payment_id == ^stripe_payment_id)
    |> Repo.all()
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

  defp create_individual_item_stripe_session(product, quantity, donate, user_id) do
    IO.puts("=== CREATING INDIVIDUAL ITEM STRIPE SESSION ===")
    IO.puts("Product ID: #{product.id}")
    IO.puts("Product Title: #{product.title}")
    IO.puts("Product Price: #{product.price}")
    IO.puts("Product Store ID: #{product.store_id}")
    IO.puts("Quantity: #{quantity}")
    IO.puts("Donate: #{donate}")

    case create_or_get_stripe_price(product) do
      {:ok, price} ->
        # Create success and cancel URLs
        success_url = "#{ShompWeb.Endpoint.url()}/payments/success?session_id={CHECKOUT_SESSION_ID}&store_slug=#{product.store.slug}"
        cancel_url = "#{ShompWeb.Endpoint.url()}/payments/cancel?store_slug=#{product.store.slug}"

        # Build line items
        line_items = [
          %{
            price: price.id,
            quantity: quantity
          }
        ]

        # Add donation as a separate line item if requested
        line_items = if donate do
          # Calculate 5% donation amount
          product_total = Decimal.mult(product.price, quantity)
          donation_amount = Decimal.mult(product_total, Decimal.new("0.05"))
          donation_cents = trunc(Decimal.to_float(donation_amount) * 100)

          donation_line_item = %{
            price_data: %{
              currency: "usd",
              product_data: %{
                name: "Donation to Shomp (5%)",
                   description: "Your donation supports infrastructure for Shomp and makes gainful creator livelihoods possible."
              },
              unit_amount: donation_cents
            },
            quantity: 1
          }
          [donation_line_item | line_items]
        else
          line_items
        end

        IO.puts("Creating Stripe session with line items: #{inspect(line_items)}")
        IO.puts("Success URL: #{success_url}")
        IO.puts("Cancel URL: #{cancel_url}")

        # Create simple Stripe session
        Stripe.Session.create(%{
          payment_method_types: ["card"],
          line_items: line_items,
          mode: "payment",
          success_url: success_url,
          cancel_url: cancel_url,
          metadata: %{
            product_id: product.id,
            product_type: product.type,
            quantity: quantity,
            donate: donate,
            user_id: user_id,
            type: "individual_item"
          }
        })

      {:error, reason} ->
        IO.puts("ERROR: Failed to create or get Stripe price: #{inspect(reason)}")
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
            unit_amount: trunc(Decimal.to_float(product.price) * 100), # Convert to cents
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

  defp create_download_for_product(payment) do
    # Only create downloads for digital products
    product = Products.get_product!(payment.product_id)
    if product.type == "digital" do
      Downloads.create_download_for_payment(payment.product_id, payment.user_id)
    else
      {:ok, :not_digital}
    end
  end

  defp handle_charge_succeeded(charge) do
    IO.puts("=== CHARGE SUCCEEDED WEBHOOK ===")

    # Handle both struct (proper webhook) and map (fallback parsing) formats
    charge_id = get_field(charge, :id, "id")
    charge_amount = get_field(charge, :amount, "amount")
    charge_metadata = get_field(charge, :metadata, "metadata")
    payment_intent_id = get_field(charge, :payment_intent, "payment_intent")

    IO.puts("Charge ID: #{charge_id}")
    IO.puts("Charge amount: #{charge_amount}")
    IO.puts("Charge metadata: #{inspect(charge_metadata)}")
    IO.puts("Payment intent ID: #{payment_intent_id}")

    # Extract store amount from metadata for seller notification
    store_amount_cents = case charge_metadata do
      %{"store_amount_cents" => amount} when is_binary(amount) -> String.to_integer(amount)
      %{"store_amount_cents" => amount} when is_integer(amount) -> amount
      _ -> charge_amount # fallback to total charge amount
    end

    # Convert cents to dollars for display
    store_amount_dollars = store_amount_cents / 100

    IO.puts("Store amount (cents): #{store_amount_cents}")
    IO.puts("Store amount (dollars): #{store_amount_dollars}")

    # Just send seller notification - Universal Order already created in payment_intent.succeeded
    IO.puts("Sending seller notification for charge succeeded...")

    # Extract product and store info from metadata for notification
    product_id = case charge_metadata do
      %{"product_id" => id} when is_binary(id) -> String.to_integer(id)
      %{"product_id" => id} when is_integer(id) -> id
      _ -> nil
    end

    store_id = case charge_metadata do
      %{"store_id" => id} -> id
      _ -> nil
    end

    universal_order_id = case charge_metadata do
      %{"universal_order_id" => id} -> id
      _ -> nil
    end

    if product_id && store_id && universal_order_id do
      # Get the universal order to find the user
      case UniversalOrders.get_universal_order_by_payment_intent(universal_order_id) do
        nil ->
          IO.puts("Universal order not found for payment intent: #{universal_order_id}")
        universal_order ->
          # Get the product and store
          product = Products.get_product!(product_id)
          store = Stores.get_store!(store_id)

          # Get the buyer's name
          buyer = Accounts.get_user!(universal_order.user_id)
          buyer_name = buyer.name || buyer.email

          # Create seller notification
          case Notifications.notify_seller_new_order(store.user_id, universal_order.universal_order_id, buyer_name, store_amount_dollars) do
            {:ok, _notification} ->
              IO.puts("Seller notification created for charge succeeded with store amount $#{store_amount_dollars}")
            {:error, reason} ->
              IO.puts("Failed to create seller notification: #{inspect(reason)}")
          end
      end
    else
      IO.puts("Missing required metadata for seller notification")
    end

    {:ok, :notification_sent}
  end

  defp handle_checkout_completed(session) do
    IO.puts("=== CHECKOUT COMPLETED WEBHOOK ===")
    IO.puts("Session ID: #{session.id}")
    IO.puts("Session metadata: #{inspect(session.metadata)}")

    # Check if this is a cart payment or single product payment
    result = case session.metadata do
      %{"cart_id" => _cart_id, "type" => "cart_order"} ->
        IO.puts("Handling cart order payment")
        # This is a cart order payment - handle the entire cart
        handle_cart_order_completed(session)

      %{"cart_id" => _cart_id} ->
        IO.puts("Handling legacy cart payment")
        # This is a legacy cart payment - handle multiple products
        handle_cart_checkout_completed(session)

      %{"type" => "individual_item"} ->
        IO.puts("Handling individual item payment")
        handle_individual_item_checkout_completed(session)

      _ ->
        IO.puts("Handling single product payment")
        # This is a single product payment
        handle_single_product_checkout_completed(session)
    end

    IO.puts("Checkout completed result: #{inspect(result)}")
    result
  end

  defp handle_single_product_checkout_completed(session) do
    IO.puts("=== SINGLE PRODUCT CHECKOUT ===")
    IO.puts("Looking for payment with session ID: #{session.id}")

    case get_payment_by_stripe_id(session.id) do
      nil ->
        IO.puts("ERROR: Payment not found for session #{session.id}")
        {:error, :payment_not_found}
      payment ->
        IO.puts("Found payment: #{payment.id}")
        case update_payment_status(payment, "succeeded") do
          {:ok, updated_payment} ->
            IO.puts("Payment status updated to succeeded")

            # Update store balance
            update_store_balance_from_payment(updated_payment)
            IO.puts("Store balance updated")

            # Create universal order for review tracking
            order_result = create_order_from_payment(updated_payment, session.id)
            IO.puts("Universal order creation result: #{inspect(order_result)}")

            # Broadcast purchase event for real-time toaster
            broadcast_purchase_event(updated_payment)

            # Try to create download, but don't fail if it doesn't work
            case create_download_for_product(updated_payment) do
              {:ok, _download} ->
                IO.puts("Download created successfully")
                # Notify seller of new order
                notify_seller_of_purchase(updated_payment)
                # Notify buyer of successful purchase
                {:ok, updated_payment}
              {:error, reason} ->
                IO.puts("Warning: Failed to create download for payment #{session.id}: #{inspect(reason)}")
                # Notify seller of new order even if download fails
                notify_seller_of_purchase(updated_payment)
                # Notify buyer of successful purchase
                {:ok, updated_payment}
            end

          {:error, reason} ->
            IO.puts("ERROR: Failed to update payment status: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp handle_individual_item_checkout_completed(session) do
    IO.puts("=== INDIVIDUAL ITEM CHECKOUT ===")
    IO.puts("Session ID: #{session.id}")
    IO.puts("Metadata: #{inspect(session.metadata)}")

    # Create payment record for the individual item
    product_id = String.to_integer(session.metadata["product_id"])
    user_id = String.to_integer(session.metadata["user_id"])
    quantity = String.to_integer(session.metadata["quantity"])
    donate = session.metadata["donate"] == "true"

    # Get the product to calculate total amount
    case Products.get_product!(product_id) do
      nil ->
        IO.puts("ERROR: Product not found for ID #{product_id}")
        {:error, :product_not_found}

      product ->
        # Calculate total amount (product price * quantity + donation if applicable)
        product_total = Decimal.mult(product.price, quantity)
        total_amount = if donate do
          donation_amount = Decimal.mult(product_total, Decimal.new("0.05"))
          Decimal.add(product_total, donation_amount)
        else
          product_total
        end

        # Create payment record
        case create_payment(%{
          amount: total_amount,
          stripe_payment_id: session.id,
          product_id: product_id,
          user_id: user_id
        }) do
          {:ok, payment} ->
            IO.puts("Payment record created: #{payment.id}")

            # Update payment status to succeeded
            case update_payment_status(payment, "succeeded") do
              {:ok, updated_payment} ->
                IO.puts("Payment status updated to succeeded")

                # Update store balance
                update_store_balance_from_payment(updated_payment)
                IO.puts("Store balance updated")

                # Create universal order for review tracking
                order_result = create_order_from_payment(updated_payment, session.id)
                IO.puts("Universal order creation result: #{inspect(order_result)}")

                # Broadcast purchase event for real-time toaster
                broadcast_purchase_event(updated_payment)

                # Create download for digital products
                case create_download_for_product(updated_payment) do
                  {:ok, _download} ->
                    IO.puts("Download created successfully")
                    # Notify seller of new order
                    notify_seller_of_purchase(updated_payment)
                    # Notify buyer of successful purchase
                    {:ok, updated_payment}
                  {:error, reason} ->
                    IO.puts("Warning: Failed to create download: #{inspect(reason)}")
                    # Notify seller of new order even if download fails
                    notify_seller_of_purchase(updated_payment)
                    # Notify buyer of successful purchase
                    {:ok, updated_payment}
                end

              {:error, reason} ->
                IO.puts("ERROR: Failed to update payment status: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, reason} ->
            IO.puts("ERROR: Failed to create payment record: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end


  defp handle_cart_order_completed(session) do
    # This is a cart order payment - create payment records for all cart items
    cart_id = String.to_integer(session.metadata["cart_id"])
    user_id = String.to_integer(session.metadata["user_id"])

    # Get the cart and create payment records for each item
    alias Shomp.Carts
    case Carts.get_cart!(cart_id) do
      nil ->
        {:error, :cart_not_found}

      cart ->
        # Create payment records for each cart item
        payments = Enum.map(cart.cart_items, fn cart_item ->
          create_payment(%{
            amount: Decimal.mult(cart_item.price, cart_item.quantity),
            stripe_payment_id: session.id,
            product_id: cart_item.product_id,
            user_id: user_id
          })
        end)

        # Check if all payments were created successfully
        case Enum.find(payments, &match?({:error, _}, &1)) do
          {:error, reason} ->
            {:error, reason}

          nil ->
            # Mark all payments as succeeded and notify sellers
            Enum.each(payments, fn {:ok, payment} ->
              update_payment_status(payment, "succeeded")
              update_store_balance_from_payment(payment)
              # Notify seller of new order
              notify_seller_of_purchase(payment)
              # Notify buyer of successful purchase
            end)

        # Create universal order for review tracking
        create_cart_order(cart, session.id, user_id)

            # Complete the cart
            Carts.complete_cart(cart_id)

            {:ok, :cart_order_completed}
        end
    end
  end

  defp handle_cart_checkout_completed(session) do
    # Get all payments for this session
    payments = list_payments_by_stripe_id(session.id)

    case payments do
      [] -> {:error, :no_payments_found}

      payments ->
        # Update all payment statuses and notify sellers
        Enum.each(payments, fn payment ->
          update_payment_status(payment, "succeeded")
          update_store_balance_from_payment(payment)
          # Notify seller of new order
          notify_seller_of_purchase(payment)
          # Notify buyer of successful purchase
          # Broadcast purchase event for real-time toaster
          broadcast_purchase_event(payment)
        end)

        # Complete the cart
        alias Shomp.Carts
        cart_id = String.to_integer(session.metadata["cart_id"])
        Carts.complete_cart(cart_id)

        {:ok, :cart_completed}
    end
  end

  defp update_store_balance_from_payment(payment) do
    # Get the product to find the store
    case Shomp.Products.get_product!(payment.product_id) do
      nil ->
        IO.puts("Warning: Product not found for payment #{payment.id}")
        {:error, :product_not_found}

      product ->
        # Update store balance using string store_id
        alias Shomp.Stores.StoreBalances
        StoreBalances.add_sale_by_store_id(product.store_id, payment.amount)
    end
  end

  defp handle_payment_succeeded(payment_intent) do
    # Handle successful payment intent
    IO.puts("=== PAYMENT SUCCEEDED ===")

    # Handle both struct (proper webhook) and map (fallback parsing) formats
    payment_intent_id = get_field(payment_intent, :id, "id")
    payment_intent_amount = get_field(payment_intent, :amount, "amount")
    payment_intent_metadata = get_field(payment_intent, :metadata, "metadata")

    IO.puts("Payment Intent ID: #{payment_intent_id}")
    IO.puts("Amount: #{payment_intent_amount}")
    IO.puts("Metadata: #{inspect(payment_intent_metadata)}")

    # Get the universal order and payment splits
    case UniversalOrders.get_universal_order_by_payment_intent(payment_intent_id) do
      nil ->
        IO.puts("No universal order found for payment intent: #{payment_intent_id}")
        {:ok, :no_order_found}

      universal_order ->
        IO.puts("Found universal order: #{universal_order.universal_order_id}")

        # Get payment splits for this order
        payment_splits = PaymentSplits.list_payment_splits_by_universal_order(universal_order.id)
        IO.puts("Found #{length(payment_splits)} payment splits")

        # Process payment splits - all are now direct transfers to Stripe accounts
        Enum.each(payment_splits, fn payment_split ->
          if payment_split.is_escrow do
            IO.puts("Processing escrow payment for store #{payment_split.store_id}")
            update_store_pending_balance(payment_split.store_id, payment_split.store_amount)

            # Update payment split status
            PaymentSplits.update_payment_split(payment_split, %{
              transfer_status: "escrow"
            })
          else
            IO.puts("Direct transfer to Stripe account for store #{payment_split.store_id}")
            IO.puts("Store amount: #{payment_split.store_amount}")
            IO.puts("Platform fee: #{payment_split.platform_fee_amount}")

            # Update payment split status to succeeded
            # Stripe automatically handles the transfer and platform fee collection
            PaymentSplits.update_payment_split(payment_split, %{
              transfer_status: "succeeded"
            })

            # Update store's available balance (for tracking purposes)
            update_store_available_balance(payment_split.store_id, payment_split.store_amount)

            # Create individual payment record for success page
            create_payment_from_payment_split(payment_split, payment_intent_id, universal_order)
          end
        end)

        # Update universal order status
        case UniversalOrders.update_universal_order(universal_order, %{
          status: "completed",
          payment_status: "paid"
        }) do
          {:ok, updated_order} ->
        # Record purchase activity and broadcast for toaster
        IO.puts("=== WEBHOOK: About to call record_purchase_activity_from_webhook ===")
        record_purchase_activity_from_webhook(updated_order, payment_intent_metadata)
            {:ok, :payment_processed}
          {:error, reason} ->
            IO.puts("ERROR: Failed to update universal order: #{inspect(reason)}")
            {:ok, :payment_processed}  # Still return success since payment was processed
        end
    end
  end

  defp handle_payment_failed(_payment_intent) do
    # Handle failed payment intent
    {:ok, :payment_failed}
  end

  defp handle_payment_intent_charge_succeeded(charge) do
    IO.puts("=== PAYMENT INTENT CHARGE SUCCEEDED WEBHOOK ===")

    # Handle both struct (proper webhook) and map (fallback parsing) formats
    charge_id = get_field(charge, :id, "id")
    charge_amount = get_field(charge, :amount, "amount")
    charge_metadata = get_field(charge, :metadata, "metadata")
    payment_intent_id = get_field(charge, :payment_intent, "payment_intent")

    IO.puts("Charge ID: #{charge_id}")
    IO.puts("Charge amount: #{charge_amount}")
    IO.puts("Charge metadata: #{inspect(charge_metadata)}")
    IO.puts("Payment intent ID: #{payment_intent_id}")

    # Extract store amount from metadata for seller notification
    store_amount_cents = case charge_metadata do
      %{"store_amount_cents" => amount} when is_binary(amount) -> String.to_integer(amount)
      %{"store_amount_cents" => amount} when is_integer(amount) -> amount
      _ -> charge_amount # fallback to total charge amount
    end

    # Convert cents to dollars for display
    store_amount_dollars = store_amount_cents / 100

    IO.puts("Store amount (cents): #{store_amount_cents}")
    IO.puts("Store amount (dollars): #{store_amount_dollars}")

    # Look up the payment by the payment intent ID OR use metadata fallback
    case get_payment_by_payment_intent_id(payment_intent_id) do
      nil ->
        IO.puts("No payment record found, trying to decrease quantity from metadata...")
        # Fallback: decrease quantity directly from charge metadata
        decrease_quantity_from_metadata(charge_metadata)

      payment ->
        IO.puts("Found payment: #{payment.id}")
        # Update payment status to succeeded
        case update_payment_status(payment, "succeeded") do
          {:ok, updated_payment} ->
            IO.puts("Payment status updated to succeeded")
            # Update store balance
            update_store_balance_from_payment(updated_payment)
            IO.puts("Store balance updated")

            # Create order for review tracking
            order_result = create_order_from_payment(updated_payment, updated_payment.stripe_payment_id)
            IO.puts("Order creation result: #{inspect(order_result)}")

            # Create download for digital products
            download_result = create_download_for_product(updated_payment)
            IO.puts("Download creation result: #{inspect(download_result)}")

            # Decrease quantity for physical products
            quantity_result = decrease_product_quantity(updated_payment)
            IO.puts("Quantity decrease result: #{inspect(quantity_result)}")

            # Notify seller of new order with store amount
            notify_seller_of_purchase_with_amount(updated_payment, store_amount_dollars)

            # Notify buyer of successful purchase

            # Broadcast payment processed event for LiveView updates
            broadcast_payment_processed(updated_payment)

            {:ok, updated_payment}

          {:error, reason} ->
            IO.puts("ERROR: Failed to update payment status: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp process_payment_split_transfer(payment_split, payment_intent) do
    IO.puts("=== PROCESSING PAYMENT SPLIT TRANSFER ===")
    IO.puts("Payment Split ID: #{payment_split.payment_split_id}")
    IO.puts("Store ID: #{payment_split.store_id}")
    IO.puts("Is Escrow: #{payment_split.is_escrow}")
    IO.puts("Store Amount: #{payment_split.store_amount}")
    IO.puts("Platform Fee: #{payment_split.platform_fee_amount}")

    if payment_split.is_escrow do
      # This is an escrow payment - just update the store's pending balance
      IO.puts("Processing escrow payment - updating store pending balance")
      update_store_pending_balance(payment_split.store_id, payment_split.store_amount)

      # Update payment split status
      PaymentSplits.update_payment_split(payment_split, %{
        transfer_status: "escrow"
      })
    else
      # This is a direct transfer - send money to the connected account
      IO.puts("Processing direct transfer to connected account")

      # Get the store's Stripe account ID
      case StoreKYCContext.get_kyc_by_store_id(payment_split.store_id) do
        nil ->
          IO.puts("No KYC found for store #{payment_split.store_id}")
          {:error, :no_kyc}

        kyc when is_nil(kyc.stripe_account_id) ->
          IO.puts("No Stripe account ID for store #{payment_split.store_id}")
          {:error, :no_stripe_account}

        kyc ->
          # Convert store amount to cents
          store_amount_cents = payment_split.store_amount
          |> Decimal.mult(100)
          |> Decimal.round(0)
          |> Decimal.to_integer()

          IO.puts("Creating transfer of #{store_amount_cents} cents to #{kyc.stripe_account_id}")

          # Create Stripe Transfer
          case Stripe.Transfer.create(%{
            amount: store_amount_cents,
            currency: "usd",
            destination: kyc.stripe_account_id,
            metadata: %{
              shomp_transfer_type: "store_payment",
              payment_split_id: payment_split.payment_split_id,
              store_id: payment_split.store_id,
              universal_order_id: payment_split.universal_order_id
            }
          }) do
            {:ok, transfer} ->
              IO.puts("Transfer created successfully: #{transfer.id}")

              # Update payment split with transfer info
              PaymentSplits.update_payment_split(payment_split, %{
                transfer_status: "succeeded",
                stripe_transfer_id: transfer.id
              })

              # Update store's available balance
              update_store_available_balance(payment_split.store_id, payment_split.store_amount)

              {:ok, transfer}

            {:error, reason} ->
              IO.puts("Transfer failed: #{inspect(reason)}")

              # Update payment split with failed status
              PaymentSplits.update_payment_split(payment_split, %{
                transfer_status: "failed"
              })

              {:error, reason}
          end
      end
    end
  end

  defp update_store_pending_balance(store_id, amount) do
    case Shomp.Stores.get_store_by_store_id(store_id) do
      nil ->
        IO.puts("Store not found: #{store_id}")
        :ok
      store ->
        new_pending = Decimal.add(store.pending_balance, amount)
        Shomp.Stores.update_store(store, %{pending_balance: new_pending})
        IO.puts("Updated store #{store_id} pending balance to #{new_pending}")
    end
  end

  defp update_store_available_balance(store_id, amount) do
    case Shomp.Stores.get_store_by_store_id(store_id) do
      nil ->
        IO.puts("Store not found: #{store_id}")
        :ok
      store ->
        new_available = Decimal.add(store.available_balance, amount)
        Shomp.Stores.update_store(store, %{available_balance: new_available})
        IO.puts("Updated store #{store_id} available balance to #{new_available}")
    end
  end


  defp create_cart_stripe_session(cart, user_id) do
    IO.puts("=== CREATING CART STRIPE SESSION ===")
    IO.puts("Cart ID: #{cart.id}")
    IO.puts("Cart Total: #{cart.total_amount}")
    IO.puts("Cart Items: #{length(cart.cart_items)}")

    # Create a single Stripe product for the entire cart order
    cart_total = cart.total_amount

    # Create a cart product name that describes the order
    product_names = cart.cart_items
    |> Enum.map(fn item -> "#{item.quantity}x #{item.product.title}" end)
    |> Enum.join(", ")

    cart_product_name = "Cart Order - #{cart.store.name}"
    cart_product_description = "Items: #{product_names}"

    IO.puts("Creating Stripe product: #{cart_product_name}")
    IO.puts("Description: #{cart_product_description}")
    IO.puts("Total amount: #{cart_total}")

    # Create a Stripe product for this cart order
    case create_cart_stripe_product(cart_product_name, cart_product_description, cart_total) do
      {:ok, stripe_product, stripe_price} ->
        IO.puts("=== CREATING STRIPE SESSION ===")
        # Create Stripe session with single line item
        success_url = "#{ShompWeb.Endpoint.url()}/payments/success?session_id={CHECKOUT_SESSION_ID}&store_slug=#{cart.store.slug}"
        cancel_url = "#{ShompWeb.Endpoint.url()}/payments/cancel?store_slug=#{cart.store.slug}"

        IO.puts("Success URL: #{success_url}")
        IO.puts("Cancel URL: #{cancel_url}")
        IO.puts("Calling Stripe.Session.create...")

        result = Stripe.Session.create(%{
          payment_method_types: ["card"],
          line_items: [
            %{
              price: stripe_price.id,
              quantity: 1
            }
          ],
          mode: "payment",
          success_url: success_url,
          cancel_url: cancel_url,
          metadata: %{
            cart_id: cart.id,
            store_id: cart.store_id,
            user_id: user_id,
            type: "cart_order"
          }
        })

        case result do
          {:ok, session} ->
            IO.puts("Stripe session created successfully: #{session.id}")
            IO.puts("Session URL: #{session.url}")
            {:ok, session}

          {:error, reason} ->
            IO.puts("Failed to create Stripe session: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_cart_stripe_product(product_name, description, total_amount) do
    IO.puts("=== CREATING STRIPE PRODUCT ===")
    IO.puts("Product Name: #{product_name}")
    IO.puts("Description: #{description}")
    IO.puts("Total Amount: #{total_amount}")

    # Convert decimal to cents for Stripe
    unit_amount = trunc(Decimal.to_float(total_amount) * 100)
    IO.puts("Unit Amount (cents): #{unit_amount}")

    # Create a Stripe product for this cart order
    IO.puts("Calling Stripe.Product.create...")
    case Stripe.Product.create(%{
      name: product_name,
      description: description
    }) do
      {:ok, stripe_product} ->
        IO.puts("Stripe product created successfully: #{stripe_product.id}")
        # Create a price for this product
        IO.puts("Calling Stripe.Price.create...")
        case Stripe.Price.create(%{
          product: stripe_product.id,
          unit_amount: unit_amount,
          currency: "usd",
          active: true
        }) do
          {:ok, stripe_price} ->
            IO.puts("Stripe price created successfully: #{stripe_price.id}")
            {:ok, stripe_product, stripe_price}

          {:error, reason} ->
            IO.puts("Failed to create Stripe price: #{inspect(reason)}")
            # Clean up the product if price creation fails
            Stripe.Product.delete(stripe_product.id)
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("Failed to create Stripe product: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_cart_payment_records(cart, user_id, session_id) do
    # Create payment records for each cart item
    payments = Enum.map(cart.cart_items, fn cart_item ->
      create_payment(%{
        amount: Decimal.mult(cart_item.price, cart_item.quantity),
        stripe_payment_id: session_id,
        product_id: cart_item.product_id,
        user_id: user_id
      })
    end)

    # Check if all payments were created successfully
    case Enum.find(payments, &match?({:error, _}, &1)) do
      {:error, reason} ->
        {:error, reason}

      nil ->
        {:ok, Enum.map(payments, fn {:ok, payment} -> payment end)}
    end
  end

  # Order creation functions for review tracking

  defp create_order_from_payment(payment, session_id) do
    alias Shomp.UniversalOrders

    IO.puts("=== CREATING UNIVERSAL ORDER FROM PAYMENT ===")
    IO.puts("Payment ID: #{payment.id}")
    IO.puts("Session ID: #{session_id}")
    IO.puts("User ID: #{payment.user_id}")
    IO.puts("Product ID: #{payment.product_id}")
    IO.puts("Amount: #{payment.amount}")

    # Check if universal order already exists for this payment intent
    case UniversalOrders.get_universal_order_by_payment_intent(session_id) do
      nil ->
        IO.puts("No existing universal order found, creating new one")

        # Get product to determine store_id
        product = Shomp.Products.get_product!(payment.product_id)
        store_id = product.store_id

        # Get user for customer info
        user = Shomp.Accounts.get_user!(payment.user_id)

        # Generate universal order ID
        universal_order_id = Ecto.UUID.generate()
        IO.puts("Generated universal order ID: #{universal_order_id}")

        # Create the universal order
        order_attrs = %{
          universal_order_id: universal_order_id,
          user_id: payment.user_id,
          stripe_payment_intent_id: session_id,
          total_amount: payment.amount,
          platform_fee_amount: Decimal.new(0), # No platform fee for single product orders
          store_id: store_id,
          status: "pending",
          payment_status: "pending",
          customer_email: user.email,
          customer_name: user.name || "Customer"
        }
        IO.puts("Creating universal order with attrs: #{inspect(order_attrs)}")

        case UniversalOrders.create_universal_order(order_attrs) do
      {:ok, universal_order} ->
        IO.puts("Universal order created successfully: #{universal_order.id}")

        # Create universal order item
        order_item_attrs = %{
          universal_order_id: universal_order.universal_order_id,
          product_immutable_id: product.immutable_id,
          store_id: store_id,
          quantity: 1,
          unit_price: payment.amount,
          total_price: payment.amount,
          store_amount: payment.amount,
          platform_fee_amount: Decimal.new(0)
        }
        IO.puts("Creating universal order item with attrs: #{inspect(order_item_attrs)}")

        case UniversalOrders.create_universal_order_item(order_item_attrs) do
          {:ok, order_item} ->
            IO.puts("Universal order item created successfully: #{order_item.id}")

            # Update order status to completed
            case UniversalOrders.update_universal_order_status(universal_order, "completed") do
              {:ok, updated_order} ->
                IO.puts("Universal order status updated to completed")

                # Record purchase activity for toaster notifications
                record_purchase_activity(updated_order, product, user)

                # Preload associations before broadcasting
                order_with_details = Shomp.Repo.preload(updated_order, [universal_order_items: :product])
                # Broadcast to LiveView that order is ready
                PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
                {:ok, updated_order}
              {:error, reason} ->
                IO.puts("ERROR: Failed to update universal order status: #{inspect(reason)}")
                # Still broadcast the order even if status update failed, but preload associations
                order_with_details = Shomp.Repo.preload(universal_order, [universal_order_items: :product])
                PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
                {:ok, universal_order}  # Return order even if status update fails
            end

          {:error, reason} ->
            IO.puts("ERROR: Failed to create universal order item: #{inspect(reason)}")
            {:ok, universal_order}  # Return order even if item creation fails
        end

      {:error, reason} ->
        IO.puts("ERROR: Failed to create universal order for payment #{payment.id}: #{inspect(reason)}")
        {:error, reason}
        end

      existing_order ->
        IO.puts("Universal order already exists: #{existing_order.id}")
        IO.puts("Updating existing order status to completed")

        # Update the existing order status to completed
        case UniversalOrders.update_universal_order_status(existing_order, "completed") do
          {:ok, updated_order} ->
            IO.puts("Existing universal order status updated to completed")

            # Record purchase activity for toaster notifications
            product = Shomp.Products.get_product!(payment.product_id)
            user = Shomp.Accounts.get_user!(payment.user_id)
            record_purchase_activity(updated_order, product, user)

            {:ok, updated_order}
          {:error, reason} ->
            IO.puts("Warning: Failed to update existing universal order status: #{inspect(reason)}")
            {:ok, existing_order}
        end
    end
  end

  defp create_cart_order(cart, session_id, user_id) do
    alias Shomp.UniversalOrders

    # Calculate total amount
    total_amount = Enum.reduce(cart.cart_items, Decimal.new(0), fn cart_item, acc ->
      Decimal.add(acc, Decimal.mult(cart_item.price, cart_item.quantity))
    end)

    # Generate universal order ID
    universal_order_id = Ecto.UUID.generate()

    # Get the first cart item to determine store_id (assuming all items are from same store)
    first_cart_item = List.first(cart.cart_items)
    store_id = first_cart_item.product.store_id

    # Get user for customer info
    user = Shomp.Accounts.get_user!(user_id)

    # Create the universal order
    case UniversalOrders.create_universal_order(%{
      universal_order_id: universal_order_id,
      user_id: user_id,
      stripe_payment_intent_id: session_id,
      total_amount: total_amount,
      platform_fee_amount: Decimal.new(0), # No platform fee for cart orders
      store_id: store_id,
      status: "pending",
      payment_status: "pending",
      customer_email: user.email,
      customer_name: user.name || "Customer"
    }) do
      {:ok, universal_order} ->
        # Create universal order items for each cart item
        Enum.each(cart.cart_items, fn cart_item ->
          UniversalOrders.create_universal_order_item(%{
            universal_order_id: universal_order.universal_order_id,
            product_immutable_id: cart_item.product.immutable_id,
            store_id: cart_item.product.store_id,
            quantity: cart_item.quantity,
            unit_price: cart_item.price,
            total_price: Decimal.mult(cart_item.price, cart_item.quantity),
            store_amount: Decimal.mult(cart_item.price, cart_item.quantity),
            platform_fee_amount: Decimal.new(0)
          })
        end)

        # Update order status to completed
        case UniversalOrders.update_universal_order_status(universal_order, "completed") do
          {:ok, updated_order} ->
            # Preload associations before broadcasting
            order_with_details = Shomp.Repo.preload(updated_order, [universal_order_items: :product])
            # Broadcast to LiveView that order is ready
            PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
            {:ok, updated_order}
          {:error, reason} ->
            IO.puts("Warning: Failed to update cart order status: #{inspect(reason)}")
            # Still broadcast the order even if status update failed, but preload associations
            order_with_details = Shomp.Repo.preload(universal_order, [universal_order_items: :product])
            PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
            {:ok, universal_order}
        end

      {:error, reason} ->
        IO.puts("Warning: Failed to create cart universal order for session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Handles Stripe Connect account.updated webhook events.
  """
  def handle_account_updated(account) do
    IO.puts("=== ACCOUNT UPDATED WEBHOOK ===")
    IO.puts("Account ID: #{account.id}")
    IO.puts("Charges enabled: #{account.charges_enabled}")
    IO.puts("Payouts enabled: #{account.payouts_enabled}")
    IO.puts("Details submitted: #{account.details_submitted}")

    case StripeConnect.handle_account_updated(account.id) do
      {:ok, _updated_kyc} ->
        IO.puts("Successfully updated KYC record for account #{account.id}")
        {:ok, :account_updated}

      {:error, :kyc_not_found} ->
        IO.puts("Warning: No KYC record found for account #{account.id}")
        {:ok, :ignored}

      {:error, reason} ->
        IO.puts("Error updating KYC record for account #{account.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Processes payout for a store - transfers escrow funds to merchant and collects platform fees.
  """
  def process_store_payout(store_id) do
    IO.puts("=== PROCESSING STORE PAYOUT ===")
    IO.puts("Store ID: #{store_id}")

    # Get store's Stripe KYC info
    case Shomp.Stores.StoreKYCContext.get_kyc_by_store_id(store_id) do
      nil ->
        {:error, :no_kyc_record}

      kyc when is_nil(kyc.stripe_account_id) ->
        {:error, :no_stripe_account}

      kyc when not kyc.charges_enabled or not kyc.payouts_enabled or not kyc.onboarding_completed ->
        {:error, :stripe_not_ready}

      kyc ->
        # Get escrow payment splits for this store
        escrow_splits = Shomp.PaymentSplits.list_escrow_payment_splits_for_store(store_id)

        if Enum.empty?(escrow_splits) do
          {:error, :no_escrow_funds}
        else
          process_escrow_payouts(kyc, escrow_splits)
        end
    end
  end

  defp process_escrow_payouts(kyc, escrow_splits) do
    IO.puts("Processing #{length(escrow_splits)} escrow splits")

    # Calculate total amounts
    total_store_amount = escrow_splits
    |> Enum.map(fn split -> split.store_amount || Decimal.new(0) end)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    total_platform_fee = escrow_splits
    |> Enum.map(fn split -> split.platform_fee_amount || Decimal.new(0) end)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    IO.puts("Total store amount: #{total_store_amount}")
    IO.puts("Total platform fee: #{total_platform_fee}")

    # Convert to cents
    store_amount_cents = total_store_amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()

    platform_fee_cents = total_platform_fee
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()

    # Process the payout
    case process_payout_transfers(kyc.stripe_account_id, store_amount_cents, platform_fee_cents, escrow_splits) do
      {:ok, transfer_results} ->
        # Update payment splits and store balances
        update_payout_success(escrow_splits, transfer_results, total_store_amount)
        {:ok, transfer_results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_payout_transfers(stripe_account_id, store_amount_cents, platform_fee_cents, escrow_splits) do
    IO.puts("=== CREATING STRIPE TRANSFERS ===")
    IO.puts("Store amount: #{store_amount_cents} cents")
    IO.puts("Platform fee: #{platform_fee_cents} cents")

    # Create transfer to merchant
    merchant_transfer = case Stripe.Transfer.create(%{
      amount: store_amount_cents,
      currency: "usd",
      destination: stripe_account_id,
      metadata: %{
        shomp_transfer_type: "merchant_payout",
        store_id: List.first(escrow_splits).store_id,
        split_count: length(escrow_splits)
      }
    }) do
      {:ok, transfer} ->
        IO.puts("Merchant transfer created: #{transfer.id}")
        {:ok, transfer}

      {:error, reason} ->
        IO.puts("Merchant transfer failed: #{inspect(reason)}")
        {:error, reason}
    end

    # Create application fee collection for platform fees (if any)
    platform_fee_result = if platform_fee_cents > 0 do
      case collect_platform_fee(platform_fee_cents, escrow_splits) do
        {:ok, fee_result} ->
          IO.puts("Platform fee collected: #{inspect(fee_result)}")
          {:ok, fee_result}

        {:error, reason} ->
          IO.puts("Platform fee collection failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:ok, :no_platform_fee}
    end

    # Return results
    case {merchant_transfer, platform_fee_result} do
      {{:ok, transfer}, {:ok, _fee_result}} ->
        {:ok, %{
          merchant_transfer: transfer,
          platform_fee: platform_fee_result,
          total_amount: store_amount_cents + platform_fee_cents
        }}

      {{:error, reason}, _} ->
        {:error, {:merchant_transfer_failed, reason}}

      {_, {:error, reason}} ->
        {:error, {:platform_fee_failed, reason}}
    end
  end

  defp collect_platform_fee(platform_fee_cents, escrow_splits) do
    # For platform fees, we need to create a separate charge to our main account
    # This simulates collecting the application fee that would have been collected
    # if the payments were direct transfers instead of escrow

    # Get the first payment intent to use as a reference
    first_split = List.first(escrow_splits)

    # Create a platform fee collection record
    platform_fee_record = %{
      amount: platform_fee_cents,
      currency: "usd",
      description: "Shomp platform fee collection",
      metadata: %{
        shomp_fee_type: "platform_fee",
        store_id: first_split.store_id,
        split_count: length(escrow_splits),
        source: "escrow_payout"
      }
    }

    # For now, we'll just log this - in production, you might want to:
    # 1. Create a separate charge to your main Stripe account
    # 2. Or track this in a separate platform_fees table
    # 3. Or handle it through your accounting system

    IO.puts("Platform fee collection record: #{inspect(platform_fee_record)}")
    {:ok, :platform_fee_tracked}
  end

  defp update_payout_success(escrow_splits, transfer_results, total_store_amount) do
    IO.puts("=== UPDATING PAYOUT SUCCESS ===")

    # Update all payment splits to succeeded
    Enum.each(escrow_splits, fn split ->
      Shomp.PaymentSplits.update_payment_split(split, %{
        transfer_status: "succeeded",
        stripe_transfer_id: transfer_results.merchant_transfer.id,
        is_escrow: false  # Remove from escrow since it's been transferred
      })
    end)

    # Update store balance
    store_id = List.first(escrow_splits).store_id
    update_store_available_balance(store_id, total_store_amount)

    IO.puts("Payout completed successfully for store #{store_id}")
  end

  @doc """
  Gets the total lifetime earnings for a store.
  """
  def get_store_total_earnings(store_id) do
    # Get all successful payments for products from this store
    query = from p in Payment,
      join: pr in Shomp.Products.Product, on: p.product_id == pr.id,
      where: pr.store_id == ^store_id and p.status == "succeeded",
      select: sum(p.amount)

    case Repo.one(query) do
      nil -> {:ok, Decimal.new(0)}
      total -> {:ok, total}
    end
  end

  # Helper function to safely get field from struct or map
  defp get_field(data, atom_key, string_key) when is_struct(data) do
    Map.get(data, atom_key)
  end

  defp get_field(data, _atom_key, string_key) when is_map(data) do
    Map.get(data, string_key)
  end

  # Decrease quantity directly from charge metadata (fallback when no payment record)
  defp decrease_quantity_from_metadata(metadata) do
    case Map.get(metadata, "product_id") do
      nil ->
        IO.puts("No product_id in metadata")
        {:error, :no_product_id}

      product_id_string ->
        try do
          product_id = String.to_integer(product_id_string)
          product = Shomp.Products.get_product_with_store!(product_id)

          if product.type == "physical" and product.quantity > 0 do
            new_quantity = product.quantity - 1

            case Shomp.Products.update_product(product, %{quantity: new_quantity}) do
              {:ok, updated_product} ->
                IO.puts("✅ Product quantity decreased from #{product.quantity} to #{new_quantity} via metadata")

                # Broadcast quantity change via PubSub
                Phoenix.PubSub.broadcast(
                  Shomp.PubSub,
                  "product_quantity:#{updated_product.id}",
                  {:quantity_changed, updated_product}
                )

                {:ok, updated_product}

              {:error, reason} ->
                IO.puts("❌ Failed to decrease product quantity: #{inspect(reason)}")
                {:error, reason}
            end
          else
            IO.puts("Product is digital or already out of stock, skipping quantity decrease")
            {:ok, :skipped}
          end
        rescue
          error ->
            IO.puts("❌ Error processing product from metadata: #{inspect(error)}")
            {:error, :product_processing_failed}
        end
    end
  end

  # Private function to decrease product quantity
  defp decrease_product_quantity(payment) do
    try do
      product = Shomp.Products.get_product_with_store!(payment.product_id)

      if product.type == "physical" and product.quantity > 0 do
        # Decrease quantity by 1
        new_quantity = product.quantity - 1

        case Shomp.Products.update_product(product, %{quantity: new_quantity}) do
          {:ok, updated_product} ->
            IO.puts("Product quantity decreased from #{product.quantity} to #{new_quantity}")
            {:ok, updated_product}

          {:error, reason} ->
            IO.puts("ERROR: Failed to decrease product quantity: #{inspect(reason)}")
            {:error, reason}
        end
      else
        IO.puts("Product is digital or already out of stock, skipping quantity decrease")
        {:ok, :skipped}
      end
    rescue
      error ->
        IO.puts("ERROR: Product not found for payment #{payment.id}: #{inspect(error)}")
        {:error, :product_not_found}
    end
  end

  @doc """
  Notifies the seller when a purchase is made.
  """
  defp notify_seller_of_purchase(payment) do
    try do
      # Get the product to find the seller
      product = Products.get_product!(payment.product_id)

      # Get the store to find the seller
      store = Stores.get_store_by_store_id!(product.store_id)

      # Get the buyer's name
      buyer = Accounts.get_user!(payment.user_id)
      buyer_name = buyer.name || buyer.email

      # Format the amount
      amount = Decimal.to_string(payment.amount, :normal)

      # Get the universal order ID for the notification link
      universal_order_id = case UniversalOrders.get_universal_order_by_payment_intent(payment.stripe_payment_id) do
        nil -> payment.id # fallback to payment ID if no universal order found
        universal_order -> universal_order.universal_order_id
      end

      # Create notification for the seller
      case Notifications.notify_seller_new_order(store.user_id, universal_order_id, buyer_name, amount) do
        {:ok, _notification} ->
          IO.puts("Seller notification created for payment #{payment.id} with universal order #{universal_order_id}")
        {:error, reason} ->
          IO.puts("Failed to create seller notification: #{inspect(reason)}")
      end

      # Send external notifications (email/SMS) based on user preferences
      alias Shomp.NotificationServices
      NotificationServices.notify_sale(store.user_id, product.name, buyer_name, amount)
    rescue
      error ->
        IO.puts("Error creating seller notification: #{inspect(error)}")
    end
  end

  @doc """
  Notifies the seller when a purchase is made with a specific store amount.
  """
  defp notify_seller_of_purchase_with_amount(payment, store_amount_dollars) do
    try do
      # Get the product to find the seller
      product = Products.get_product!(payment.product_id)

      # Get the store to find the seller
      store = Stores.get_store_by_store_id!(product.store_id)

      # Get the buyer's name
      buyer = Accounts.get_user!(payment.user_id)
      buyer_name = buyer.name || buyer.email

      # Format the store amount (already in dollars)
      amount = :erlang.float_to_binary(store_amount_dollars, decimals: 2)

      # Get the universal order ID for the notification link
      universal_order_id = case UniversalOrders.get_universal_order_by_payment_intent(payment.stripe_payment_id) do
        nil -> payment.id # fallback to payment ID if no universal order found
        universal_order -> universal_order.universal_order_id
      end

      # Create notification for the seller
      case Notifications.notify_seller_new_order(store.user_id, universal_order_id, buyer_name, amount) do
        {:ok, _notification} ->
          IO.puts("Seller notification created for payment #{payment.id} with store amount $#{amount} and universal order #{universal_order_id}")
        {:error, reason} ->
          IO.puts("Failed to create seller notification: #{inspect(reason)}")
      end

      # Send external notifications (email/SMS) based on user preferences
      alias Shomp.NotificationServices
      NotificationServices.notify_sale(store.user_id, product.name, buyer_name, amount)
    rescue
      error ->
        IO.puts("Error creating seller notification: #{inspect(error)}")
    end
  end



  @doc """
  Creates a payment record from a payment split for success page display.
  """
  defp create_payment_from_payment_split(payment_split, payment_intent_id, universal_order) do
    try do
      # Get the universal order item to find the product
      IO.puts("Looking for order item with universal_order_id: #{universal_order.universal_order_id} and store_id: #{payment_split.store_id}")
      order_item = Repo.get_by!(UniversalOrders.UniversalOrderItem,
        universal_order_id: universal_order.universal_order_id,
        store_id: payment_split.store_id
      )
      IO.puts("Found order item: #{inspect(order_item.id)}")

      # Get the product from the order item
      product = Repo.get_by!(Products.Product, immutable_id: order_item.product_immutable_id)

      # Create payment record
      payment_attrs = %{
        user_id: universal_order.user_id,
        product_id: product.id,
        product_immutable_id: product.immutable_id,
        amount: payment_split.total_amount, # Total amount (store + platform fee)
        stripe_payment_id: payment_intent_id,
        status: "succeeded"
      }

      case create_payment(payment_attrs) do
        {:ok, payment} ->
          IO.puts("Created payment record #{payment.id} for payment split #{payment_split.payment_split_id}")

          # Create order for review tracking
          create_order_from_payment(payment, payment_intent_id)

          # Create download for digital products
          create_download_for_product(payment)

          # Decrease quantity for physical products
          decrease_product_quantity(payment)

          # Notify seller of new order with store amount
          store_amount_dollars = Decimal.to_float(payment_split.store_amount)
          notify_seller_of_purchase_with_amount(payment, store_amount_dollars)


          # Broadcast payment processed event for LiveView updates
          broadcast_payment_processed(payment)

          {:ok, payment}

        {:error, reason} ->
          IO.puts("Failed to create payment record: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        IO.puts("Error creating payment from payment split: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Broadcasts payment processed event for LiveView updates.
  """
  defp broadcast_payment_processed(payment) do
    try do
      Phoenix.PubSub.broadcast(
        Shomp.PubSub,
        "payment_processed:#{payment.stripe_payment_id}",
        {:payment_processed, payment.stripe_payment_id}
      )
      IO.puts("Broadcasted payment processed event for payment #{payment.id}")
    rescue
      error ->
        IO.puts("Error broadcasting payment processed event: #{inspect(error)}")
    end
  end

  @doc """
  Records purchase activity for toaster notifications.
  """
  defp record_purchase_activity(order, product, buyer) do
    try do
      alias Shomp.PurchaseActivities
      PurchaseActivities.record_purchase(order, product, buyer)
      IO.puts("Recorded purchase activity for order #{order.id}")
    rescue
      error ->
        IO.puts("Error recording purchase activity: #{inspect(error)}")
    end
  end

  @doc """
  Broadcasts a purchase event for real-time toaster notifications.
  """
  defp broadcast_purchase_event(payment) do
    try do
      # Get the product and user details for the toaster
      product = Products.get_product!(payment.product_id)
      user = Accounts.get_user!(payment.user_id)

      # Create the purchase activity data for the toaster
      activity_data = %{
        id: payment.id,
        buyer_initials: get_buyer_initials(user),
        buyer_location: get_buyer_location(user),
        product_title: product.title,
        product_slug: product.slug,
        product_url: build_product_url(product),
        amount: Decimal.to_float(payment.amount),
        inserted_at: DateTime.utc_now()
      }

        # Broadcast to all connected clients (both LiveView and Channel)
        Phoenix.PubSub.broadcast(Shomp.PubSub, "purchase_activities", {:purchase_completed, activity_data})
        IO.puts("Broadcasted purchase event for payment #{payment.id}")
    rescue
      error ->
        IO.puts("Error broadcasting purchase event: #{inspect(error)}")
    end
  end

  defp get_buyer_initials(user) do
    if user.name do
      user.name
      |> String.split()
      |> Enum.map(&String.first/1)
      |> Enum.join("")
      |> String.upcase()
    else
      String.first(user.email) |> String.upcase()
    end
  end

  defp get_buyer_location(user) do
    user.location || "Unknown Location"
  end

  defp build_product_url(product) do
    # Build the product URL using the product slug
    if product.slug do
      "/products/#{product.slug}"
    else
      "/products/#{product.id}"
    end
  end

  @doc """
  Records purchase activity and broadcasts toaster event from webhook data.
  """
  defp record_purchase_activity_from_webhook(universal_order, metadata) do
    IO.puts("=== WEBHOOK: record_purchase_activity_from_webhook called ===")
    IO.puts("Universal Order ID: #{universal_order.id}")
    IO.puts("Metadata: #{inspect(metadata)}")

    try do
      # Extract product and user info from metadata
      product_id = case metadata do
        %{"product_id" => id} when is_binary(id) -> String.to_integer(id)
        %{"product_id" => id} when is_integer(id) -> id
        _ -> nil
      end

      IO.puts("Extracted product_id: #{inspect(product_id)}")

      if product_id do
        # Get product and user
        product = Products.get_product!(product_id)
        user = Accounts.get_user!(universal_order.user_id)

        # Record purchase activity
        record_purchase_activity(universal_order, product, user)

        # Broadcast toaster event
        activity_data = %{
          id: universal_order.id,
          buyer_initials: get_buyer_initials(user),
          buyer_location: get_buyer_location(user),
          product_title: product.title,
          product_slug: product.slug,
          product_url: build_product_url(product),
          amount: Decimal.to_float(universal_order.total_amount),
          inserted_at: DateTime.utc_now()
        }

          # Broadcast to all connected clients (both LiveView and Channel)
          Phoenix.PubSub.broadcast(Shomp.PubSub, "purchase_activities", {:purchase_completed, activity_data})
          IO.puts("Broadcasted purchase event from webhook for order #{universal_order.id}")
      else
        IO.puts("No product_id in metadata, skipping toaster broadcast")
      end
    rescue
      error ->
        IO.puts("Error recording purchase activity from webhook: #{inspect(error)}")
    end
  end

end
