defmodule ShompWeb.PaymentIntentController do
  use ShompWeb, :controller

  alias Shomp.Products
  alias Shomp.Stores
  alias Shomp.UniversalOrders
  alias Shomp.PaymentSplits

  def create(conn, %{"product_id" => product_id, "universal_order_id" => universal_order_id, "donate" => donate, "customer_email" => customer_email, "customer_name" => customer_name} = params) do
    IO.puts("=== PAYMENT INTENT CONTROLLER DEBUG ===")
    IO.puts("Received params: #{inspect(params)}")
    IO.puts("Product ID: #{product_id}")
    IO.puts("Universal Order ID: #{universal_order_id}")
    IO.puts("Donate: #{donate}")
    IO.puts("Customer Email: #{customer_email}")
    IO.puts("Customer Name: #{customer_name}")
    IO.puts("User ID: #{conn.assigns.current_scope.user.id}")

    # Convert product_id to integer
    product_id = String.to_integer(product_id)
    IO.puts("Converted Product ID: #{product_id}")

    # Validate required fields
    if is_nil(customer_email) or customer_email == "" do
      IO.puts("ERROR: Email address is required but was nil or empty")
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Email address is required"})
    else
      process_payment_intent(conn, product_id, universal_order_id, donate, customer_email, customer_name, params)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: product_id, universal_order_id, donate, customer_email, customer_name"})
  end

  defp process_payment_intent(conn, product_id, universal_order_id, donate, customer_email, customer_name, params) do
    IO.puts("=== PROCESSING PAYMENT INTENT ===")
    user_id = conn.assigns.current_scope.user.id
    IO.puts("User ID: #{user_id}")

    IO.puts("Fetching product with ID: #{product_id}")
    product = Products.get_product_with_store!(product_id)
    IO.puts("Product found: #{product.title}")
    IO.puts("Product price: #{product.price}")
    IO.puts("Product store ID: #{product.store_id}")

    # Calculate amounts
    platform_fee_rate = Decimal.new("0.05")
    platform_fee_amount = if donate do
      Decimal.mult(product.price, platform_fee_rate)
    else
      Decimal.new("0")
    end

    total_amount = if donate do
      Decimal.add(product.price, platform_fee_amount)
    else
      product.price
    end

    IO.puts("Platform fee amount: #{platform_fee_amount}")
    IO.puts("Total amount: #{total_amount}")

    # Convert to cents for Stripe
    total_amount_cents = total_amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()

    platform_fee_cents = platform_fee_amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()

    store_amount_cents = total_amount_cents - platform_fee_cents

    IO.puts("Total amount cents: #{total_amount_cents}")
    IO.puts("Platform fee cents: #{platform_fee_cents}")
    IO.puts("Store amount cents: #{store_amount_cents}")

    # Create Stripe Payment Intent
    case create_stripe_payment_intent(product, total_amount_cents, platform_fee_cents, universal_order_id) do
      {:ok, payment_intent} ->
        # Create universal order record
        case create_universal_order(product, user_id, payment_intent.id, total_amount, platform_fee_amount, universal_order_id, customer_email, customer_name, params) do
          {:ok, universal_order} ->
            # Create universal order item
            case create_universal_order_item(universal_order, product, store_amount_cents, platform_fee_cents) do
              {:ok, _order_item} ->
                # Create payment split record
                case create_payment_split(universal_order, product, payment_intent.id, store_amount_cents, platform_fee_cents) do
                  {:ok, payment_split} ->
                    # Update store balance if this is an escrow payment
                    if payment_split.is_escrow do
                      store_amount_decimal = Decimal.div(Decimal.new(store_amount_cents), Decimal.new(100))
                      update_store_pending_balance(product.store_id, store_amount_decimal)
                    end

                    json(conn, %{
                      client_secret: payment_intent.client_secret,
                      payment_intent_id: payment_intent.id
                    })

                  {:error, changeset} ->
                    error_message = format_changeset_errors(changeset)
                    conn
                    |> put_status(:unprocessable_entity)
                    |> json(%{error: "Failed to create payment split: #{error_message}"})
                end

              {:error, changeset} ->
                error_message = format_changeset_errors(changeset)
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Failed to create order item: #{error_message}"})
            end

          {:error, changeset} ->
            error_message = format_changeset_errors(changeset)
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to create universal order: #{error_message}"})
        end

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create payment intent: #{inspect(reason)}"})
    end
  end

  defp create_stripe_payment_intent(product, total_amount_cents, platform_fee_cents, universal_order_id) do
    IO.puts("=== CREATING STRIPE PAYMENT INTENT ===")
    IO.puts("Product ID: #{product.id}")
    IO.puts("Store ID: #{product.store_id}")
    IO.puts("Total amount cents: #{total_amount_cents}")
    IO.puts("Platform fee cents: #{platform_fee_cents}")
    IO.puts("Universal order ID: #{universal_order_id}")

    # Get store's Stripe account ID
    store_kyc = Shomp.Stores.StoreKYCContext.get_kyc_by_store_id(product.store_id)
    IO.puts("Store KYC found: #{!!store_kyc}")
    if store_kyc do
      IO.puts("Store KYC Stripe account ID: #{store_kyc.stripe_account_id}")
    end

    # Now that we create Stripe accounts immediately, we should always have a stripe_account_id
    if store_kyc && store_kyc.stripe_account_id do
      IO.puts("Creating payment intent with direct transfer to Stripe account: #{store_kyc.stripe_account_id}")

      payment_intent_params = %{
        amount: total_amount_cents,
        currency: "usd",
        application_fee_amount: platform_fee_cents,
        transfer_data: %{
          destination: store_kyc.stripe_account_id
        },
        metadata: %{
          universal_order_id: universal_order_id,
          product_id: product.id,
          store_id: product.store_id,
          payment_type: "direct_transfer",
          platform_fee_cents: platform_fee_cents,
          store_amount_cents: total_amount_cents - platform_fee_cents
        }
      }

      IO.puts("Payment intent params: #{inspect(payment_intent_params)}")

      # Always transfer to merchant's Stripe account (even in restricted mode)
      # Stripe will hold the funds until KYC is complete, then release them automatically
      Stripe.PaymentIntent.create(payment_intent_params)
    else
      IO.puts("Creating fallback payment intent (no transfer)")

      payment_intent_params = %{
        amount: total_amount_cents,
        currency: "usd",
        metadata: %{
          universal_order_id: universal_order_id,
          product_id: product.id,
          store_id: product.store_id,
          payment_type: "fallback",
          platform_fee_cents: platform_fee_cents,
          store_amount_cents: total_amount_cents - platform_fee_cents
        }
      }

      IO.puts("Fallback payment intent params: #{inspect(payment_intent_params)}")

      # Fallback - this shouldn't happen now that we create accounts immediately
      # But if it does, create a regular payment intent (no transfer)
      Stripe.PaymentIntent.create(payment_intent_params)
    end
  end

  defp create_universal_order(product, user_id, payment_intent_id, total_amount, platform_fee_amount, universal_order_id, customer_email, customer_name, params) do
    # Prepare order data
    order_data = %{
      universal_order_id: universal_order_id,
      user_id: user_id,
      stripe_payment_intent_id: payment_intent_id,
      total_amount: total_amount,
      platform_fee_amount: platform_fee_amount,
      store_id: product.store_id,
      status: "pending",
      payment_status: "pending",
      customer_email: customer_email,
      customer_name: customer_name
    }

    # Add shipping address for physical products
    order_data = if product.type == "physical" && params["shipping_address"] do
      shipping = params["shipping_address"]
      Map.merge(order_data, %{
        shipping_address_line1: shipping["line1"],
        shipping_address_line2: shipping["line2"],
        shipping_address_city: shipping["city"],
        shipping_address_state: shipping["state"],
        shipping_address_postal_code: shipping["postal_code"],
        shipping_address_country: shipping["country"]
      })
    else
      order_data
    end

    UniversalOrders.create_universal_order(order_data)
  end

  defp create_universal_order_item(universal_order, product, store_amount_cents, platform_fee_cents) do
    store_amount = Decimal.div(Decimal.new(store_amount_cents), Decimal.new(100))
    platform_fee_amount = Decimal.div(Decimal.new(platform_fee_cents), Decimal.new(100))

    order_item_data = %{
      universal_order_id: universal_order.universal_order_id,
      product_immutable_id: product.immutable_id,
      store_id: product.store_id,
      quantity: 1,
      unit_price: product.price,
      total_price: product.price,
      store_amount: store_amount,
      platform_fee_amount: platform_fee_amount
    }

    IO.puts("=== CREATING UNIVERSAL ORDER ITEM ===")
    IO.puts("Order item data: #{inspect(order_item_data)}")

    case UniversalOrders.create_universal_order_item(order_item_data) do
      {:ok, order_item} ->
        IO.puts("Universal order item created successfully: #{inspect(order_item)}")
        {:ok, order_item}
      {:error, changeset} ->
        IO.puts("=== UNIVERSAL ORDER ITEM CREATION FAILED ===")
        IO.puts("Changeset errors: #{inspect(changeset.errors)}")
        IO.puts("Changeset changes: #{inspect(changeset.changes)}")
        IO.puts("Changeset data: #{inspect(changeset.data)}")
        IO.puts("Changeset valid?: #{inspect(changeset.valid?)}")
        {:error, changeset}
    end
  end

  defp create_payment_split(universal_order, product, payment_intent_id, store_amount_cents, platform_fee_cents) do
    # Ensure Stripe account exists for this store
    case Shomp.Stores.ensure_stripe_connected_account(product.store_id) do
      {:ok, _stripe_account_id} ->
        # Stripe account exists, proceed with payment split creation
        create_payment_split_with_kyc(universal_order, product, payment_intent_id, store_amount_cents, platform_fee_cents)
      {:error, reason} ->
        IO.puts("Failed to ensure Stripe account for store #{product.store_id}: #{inspect(reason)}")
        # Fallback to escrow payment if Stripe account creation fails
        create_payment_split_with_kyc(universal_order, product, payment_intent_id, store_amount_cents, platform_fee_cents, true)
    end
  end

  defp create_payment_split_with_kyc(universal_order, product, payment_intent_id, store_amount_cents, platform_fee_cents, force_escrow \\ false) do
    store_kyc = Shomp.Stores.StoreKYCContext.get_kyc_by_store_id(product.store_id)

    # Convert cents back to decimal for storage
    store_amount = Decimal.from_float(store_amount_cents / 100) |> Decimal.round(2)
    platform_fee_amount = Decimal.from_float(platform_fee_cents / 100) |> Decimal.round(2)
    total_amount = Decimal.add(store_amount, platform_fee_amount)

    # Generate payment split ID
    payment_split_id = generate_payment_split_id()

    # With the new approach, we always do direct transfers to Stripe accounts
    # Stripe handles holding funds in restricted mode until KYC is complete
    is_escrow = force_escrow || !store_kyc || !store_kyc.stripe_account_id

    PaymentSplits.create_payment_split(%{
      payment_split_id: payment_split_id,
      universal_order_id: universal_order.id,
      stripe_payment_intent_id: payment_intent_id,
      store_id: product.store_id,
      stripe_account_id: if(store_kyc, do: store_kyc.stripe_account_id, else: nil),
      store_amount: store_amount,
      platform_fee_amount: platform_fee_amount,
      total_amount: total_amount,
      transfer_status: if(is_escrow, do: "escrow", else: "pending"),
      refund_status: "none",
      is_escrow: is_escrow
    })
  end

  defp generate_payment_split_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false) |> String.slice(0, 8)
    "PS_#{timestamp}_#{random}"
  end

  defp format_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp update_store_pending_balance(store_id, amount) do
    case Shomp.Stores.get_store_by_store_id(store_id) do
      nil -> :ok  # Store not found, skip update
      store ->
        new_pending = Decimal.add(store.pending_balance, amount)
        Shomp.Stores.update_store(store, %{pending_balance: new_pending})
    end
  end
end
