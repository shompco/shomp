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
      {:ok, session}
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
    if payment.product.type == "digital" do
      Downloads.create_download_for_payment(payment.product_id, payment.user_id)
    else
      {:ok, :not_digital}
    end
  end

  defp handle_charge_succeeded(charge) do
    IO.puts("=== CHARGE SUCCEEDED WEBHOOK ===")
    IO.puts("Charge ID: #{charge.id}")
    IO.puts("Charge amount: #{charge.amount}")
    IO.puts("Charge metadata: #{inspect(charge.metadata)}")
    
    # Get the payment intent ID from the charge
    payment_intent_id = charge.payment_intent
    
    # Look up the payment by the payment intent ID
    case get_payment_by_payment_intent_id(payment_intent_id) do
      nil ->
        IO.puts("ERROR: No payment found for payment intent #{payment_intent_id}")
        {:error, :payment_not_found}
      
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
            
            {:ok, updated_payment}
          
          {:error, reason} ->
            IO.puts("ERROR: Failed to update payment status: #{inspect(reason)}")
            {:error, reason}
        end
    end
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
            
            # Create order for review tracking
            order_result = create_order_from_payment(updated_payment, session.id)
            IO.puts("Order creation result: #{inspect(order_result)}")
            
            # Try to create download, but don't fail if it doesn't work
            case create_download_for_product(updated_payment) do
              {:ok, _download} -> 
                IO.puts("Download created successfully")
                {:ok, updated_payment}
              {:error, reason} -> 
                IO.puts("Warning: Failed to create download for payment #{session.id}: #{inspect(reason)}")
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
                
                # Create order for review tracking
                order_result = create_order_from_payment(updated_payment, session.id)
                IO.puts("Order creation result: #{inspect(order_result)}")
                
                # Create download for digital products
                case create_download_for_product(updated_payment) do
                  {:ok, _download} -> 
                    IO.puts("Download created successfully")
                    {:ok, updated_payment}
                  {:error, reason} -> 
                    IO.puts("Warning: Failed to create download: #{inspect(reason)}")
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
            # Mark all payments as succeeded
            Enum.each(payments, fn {:ok, payment} ->
              update_payment_status(payment, "succeeded")
              update_store_balance_from_payment(payment)
            end)
            
            # Create order for review tracking
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
        # Update all payment statuses
        Enum.each(payments, fn payment ->
          update_payment_status(payment, "succeeded")
          update_store_balance_from_payment(payment)
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
    IO.puts("Payment Intent ID: #{payment_intent.id}")
    IO.puts("Amount: #{payment_intent.amount}")
    IO.puts("Metadata: #{inspect(payment_intent.metadata)}")
    
    # Get the universal order and payment splits
    case UniversalOrders.get_universal_order_by_payment_intent(payment_intent.id) do
      nil ->
        IO.puts("No universal order found for payment intent: #{payment_intent.id}")
        {:ok, :no_order_found}
      
      universal_order ->
        IO.puts("Found universal order: #{universal_order.universal_order_id}")
        
        # Get payment splits for this order
        payment_splits = PaymentSplits.list_payment_splits_by_universal_order(universal_order.id)
        IO.puts("Found #{length(payment_splits)} payment splits")
        
        # For direct transfers, Stripe handles the transfer automatically
        # For escrow payments, update the store's pending balance
        Enum.each(payment_splits, fn payment_split ->
          if payment_split.is_escrow do
            IO.puts("Processing escrow payment for store #{payment_split.store_id}")
            update_store_pending_balance(payment_split.store_id, payment_split.store_amount)
            
            # Update payment split status
            PaymentSplits.update_payment_split(payment_split, %{
              transfer_status: "escrow"
            })
          else
            IO.puts("Direct transfer handled automatically by Stripe for store #{payment_split.store_id}")
            
            # Update payment split status
            PaymentSplits.update_payment_split(payment_split, %{
              transfer_status: "succeeded"
            })
            
            # Update store's available balance
            update_store_available_balance(payment_split.store_id, payment_split.store_amount)
          end
        end)
        
        # Update universal order status
        UniversalOrders.update_universal_order(universal_order, %{
          status: "completed",
          payment_status: "succeeded"
        })
        
        {:ok, :payment_processed}
    end
  end

  defp handle_payment_failed(_payment_intent) do
    # Handle failed payment intent
    {:ok, :payment_failed}
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
    alias Shomp.Orders
    
    IO.puts("=== CREATING ORDER FROM PAYMENT ===")
    IO.puts("Payment ID: #{payment.id}")
    IO.puts("Session ID: #{session_id}")
    IO.puts("User ID: #{payment.user_id}")
    IO.puts("Product ID: #{payment.product_id}")
    IO.puts("Amount: #{payment.amount}")
    
    # Generate immutable ID for the order
    immutable_id = Ecto.UUID.generate()
    IO.puts("Generated order immutable ID: #{immutable_id}")
    
    # Create the order
    order_attrs = %{
      immutable_id: immutable_id,
      total_amount: payment.amount,
      stripe_session_id: session_id,
      user_id: payment.user_id
    }
    IO.puts("Creating order with attrs: #{inspect(order_attrs)}")
    
    case Orders.create_order(order_attrs) do
      {:ok, order} ->
        IO.puts("Order created successfully: #{order.id}")
        
        # Create order item
        order_item_attrs = %{
          order_id: order.id,
          product_id: payment.product_id,
          quantity: 1,
          price: payment.amount
        }
        IO.puts("Creating order item with attrs: #{inspect(order_item_attrs)}")
        
        case Orders.create_order_item(order_item_attrs) do
          {:ok, order_item} ->
            IO.puts("Order item created successfully: #{order_item.id}")
            
            # Update order status to completed
            case Orders.update_order_status(order, "completed") do
              {:ok, updated_order} ->
                IO.puts("Order status updated to completed")
                # Preload associations before broadcasting
                order_with_details = Shomp.Repo.preload(updated_order, [order_items: :product])
                # Broadcast to LiveView that order is ready
                PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
                {:ok, updated_order}
              {:error, reason} ->
                IO.puts("ERROR: Failed to update order status: #{inspect(reason)}")
                # Still broadcast the order even if status update failed, but preload associations
                order_with_details = Shomp.Repo.preload(order, [order_items: :product])
                PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
                {:ok, order}  # Return order even if status update fails
            end
          
          {:error, reason} ->
            IO.puts("ERROR: Failed to create order item: #{inspect(reason)}")
            {:ok, order}  # Return order even if item creation fails
        end
        
      {:error, reason} ->
        IO.puts("ERROR: Failed to create order for payment #{payment.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_cart_order(cart, session_id, user_id) do
    alias Shomp.Orders
    
    # Calculate total amount
    total_amount = Enum.reduce(cart.cart_items, Decimal.new(0), fn cart_item, acc ->
      Decimal.add(acc, Decimal.mult(cart_item.price, cart_item.quantity))
    end)
    
    # Generate immutable ID for the order
    immutable_id = Ecto.UUID.generate()
    
    # Create the order
    case Orders.create_order(%{
      immutable_id: immutable_id,
      total_amount: total_amount,
      stripe_session_id: session_id,
      user_id: user_id
    }) do
      {:ok, order} ->
        # Create order items for each cart item
        Enum.each(cart.cart_items, fn cart_item ->
          Orders.create_order_item(%{
            order_id: order.id,
            product_id: cart_item.product_id,
            quantity: cart_item.quantity,
            price: cart_item.price
          })
        end)
        
        # Update order status to completed
        case Orders.update_order_status(order, "completed") do
          {:ok, updated_order} ->
            # Preload associations before broadcasting
            order_with_details = Shomp.Repo.preload(updated_order, [order_items: :product])
            # Broadcast to LiveView that order is ready
            PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
            {:ok, updated_order}
          {:error, reason} ->
            IO.puts("Warning: Failed to update cart order status: #{inspect(reason)}")
            # Still broadcast the order even if status update failed, but preload associations
            order_with_details = Shomp.Repo.preload(order, [order_items: :product])
            PubSub.broadcast(Shomp.PubSub, "order_created:#{session_id}", {:order_created, order_with_details})
            {:ok, order}
        end
      
      {:error, reason} ->
        IO.puts("Warning: Failed to create cart order for session #{session_id}: #{inspect(reason)}")
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
end
