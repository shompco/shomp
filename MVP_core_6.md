# MVP Core 6: Custom Checkout with Stripe Elements & Connect Payment Splitting

## Overview
This document outlines the implementation of a custom checkout page using Stripe Elements with Stripe Connect for payment splitting among multiple merchants, including an optional 5% platform donation fee enabled by default.

## Current System Analysis

### Existing Payment Infrastructure
- **Stripe Integration**: Basic Stripe checkout sessions for individual products and carts
- **Stripe Connect**: Express accounts for store onboarding and balance tracking
- **Cart System**: Store-specific carts (one cart per store per user)
- **Payment Processing**: Webhook-based payment confirmation and store balance updates
- **Current Limitation**: No multi-store checkout or payment splitting

### Key Gaps to Address
- No custom checkout UI (currently redirects to Stripe Checkout)
- No payment splitting for multi-store purchases
- No platform fee collection mechanism
- No unified checkout for items from different stores
- Limited payment method customization

## 1. Enhanced Cart System for Multi-Store Checkout

### A. Unified Cart Schema
```elixir
# Migration: create_unified_carts
defmodule Shomp.Repo.Migrations.CreateUnifiedCarts do
  use Ecto.Migration

  def change do
    create table(:unified_carts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, default: "active" # active, abandoned, completed
      add :total_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :platform_fee_enabled, :boolean, default: true
      add :shipping_address_id, references(:addresses, on_delete: :nilify_all)
      add :billing_address_id, references(:addresses, on_delete: :nilify_all)
      
      timestamps(type: :utc_datetime)
    end

    create index(:unified_carts, [:user_id])
    create index(:unified_carts, [:status])
  end
end

# Migration: create_unified_cart_items
defmodule Shomp.Repo.Migrations.CreateUnifiedCartItems do
  use Ecto.Migration

  def change do
    create table(:unified_cart_items) do
      add :unified_cart_id, references(:unified_carts, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :store_id, :string, null: false # Store's immutable store_id
      add :quantity, :integer, default: 1
      add :price, :decimal, precision: 10, scale: 2 # Price at time of adding to cart
      add :store_amount, :decimal, precision: 10, scale: 2 # Amount going to store
      add :platform_fee_amount, :decimal, precision: 10, scale: 2 # Platform fee for this item
      
      timestamps(type: :utc_datetime)
    end

    create index(:unified_cart_items, [:unified_cart_id])
    create index(:unified_cart_items, [:store_id])
    create unique_index(:unified_cart_items, [:unified_cart_id, :product_id])
  end
end
```

### B. Unified Cart Context
```elixir
# lib/shomp/unified_carts.ex
defmodule Shomp.UnifiedCarts do
  @moduledoc """
  The UnifiedCarts context for managing multi-store shopping carts.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.UnifiedCarts.{UnifiedCart, UnifiedCartItem}
  alias Shomp.Products
  alias Shomp.Stores

  @platform_fee_rate 0.05 # 5% platform fee

  def get_or_create_unified_cart(user_id) do
    case get_active_unified_cart(user_id) do
      nil ->
        create_unified_cart(%{user_id: user_id})
      cart ->
        {:ok, cart}
    end
  end

  def get_active_unified_cart(user_id) do
    UnifiedCart
    |> where([c], c.user_id == ^user_id and c.status == "active")
    |> preload([unified_cart_items: [product: []]])
    |> Repo.one()
  end

  def add_to_unified_cart(user_id, product_id, quantity \\ 1) do
    product = Products.get_product!(product_id)
    
    with {:ok, cart} <- get_or_create_unified_cart(user_id),
         {:ok, cart_item} <- create_or_update_cart_item(cart, product, quantity) do
      recalculate_cart_totals(cart.id)
      {:ok, cart_item}
    end
  end

  defp create_or_update_cart_item(cart, product, quantity) do
    case get_cart_item(cart.id, product.id) do
      nil ->
        create_cart_item(%{
          unified_cart_id: cart.id,
          product_id: product.id,
          store_id: product.store_id,
          quantity: quantity,
          price: product.price
        })
      existing_item ->
        update_cart_item_quantity(existing_item, existing_item.quantity + quantity)
    end
  end

  defp calculate_item_amounts(price, quantity, platform_fee_enabled) do
    total_amount = Decimal.mult(price, quantity)
    
    if platform_fee_enabled do
      platform_fee = Decimal.mult(total_amount, Decimal.new(@platform_fee_rate))
      store_amount = Decimal.sub(total_amount, platform_fee)
      {store_amount, platform_fee}
    else
      {total_amount, Decimal.new(0)}
    end
  end

  defp calculate_amounts_in_cents(amount) do
    amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()
  end

  def recalculate_cart_totals(cart_id) do
    cart = get_unified_cart!(cart_id)
    
    {total_amount, platform_fee_total} = 
      cart.unified_cart_items
      |> Enum.reduce({Decimal.new(0), Decimal.new(0)}, fn item, {total_acc, fee_acc} ->
        {store_amount, platform_fee} = calculate_item_amounts(
          item.price, 
          item.quantity, 
          cart.platform_fee_enabled
        )
        
        # Update the cart item with calculated amounts
        update_cart_item_amounts(item, store_amount, platform_fee)
        
        {Decimal.add(total_acc, Decimal.add(store_amount, platform_fee)), 
         Decimal.add(fee_acc, platform_fee)}
      end)
    
    cart
    |> UnifiedCart.totals_changeset(%{
      total_amount: total_amount,
      platform_fee_amount: platform_fee_total
    })
    |> Repo.update()
  end

  def get_cart_by_store(cart_id, store_id) do
    UnifiedCartItem
    |> where([i], i.unified_cart_id == ^cart_id and i.store_id == ^store_id)
    |> preload([product: []])
    |> Repo.all()
  end

  def get_cart_summary(cart_id) do
    cart = get_unified_cart!(cart_id)
    
    # Group items by store
    store_groups = 
      cart.unified_cart_items
      |> Enum.group_by(& &1.store_id)
      |> Enum.map(fn {store_id, items} ->
        store = Stores.get_store_by_store_id(store_id)
        store_total = Enum.reduce(items, Decimal.new(0), fn item, acc ->
          Decimal.add(acc, Decimal.add(item.store_amount, item.platform_fee_amount))
        end)
        
        %{
          store: store,
          items: items,
          total: store_total
        }
      end)
    
    %{
      cart: cart,
      store_groups: store_groups,
      total_amount: cart.total_amount,
      platform_fee_amount: cart.platform_fee_amount
    }
  end
end
```

## 2. Stripe Elements Integration

### A. Frontend Stripe Elements Setup
```javascript
// assets/js/stripe_elements.js
import { loadStripe } from '@stripe/stripe-js';
import { Elements, CardElement, useStripe, useElements } from '@stripe/react-stripe-js';

const stripePromise = loadStripe(window.stripePublishableKey);

const CheckoutForm = ({ cartSummary, onPaymentSuccess, onPaymentError }) => {
  const stripe = useStripe();
  const elements = useElements();

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!stripe || !elements) {
      return;
    }

    const cardElement = elements.getElement(CardElement);

    // Create payment intent on the server
    const { error: backendError, clientSecret } = await fetch('/api/payment-intents', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        cart_id: cartSummary.cart.id,
        platform_fee_enabled: cartSummary.cart.platform_fee_enabled
      })
    }).then(res => res.json());

    if (backendError) {
      onPaymentError(backendError);
      return;
    }

    // Confirm payment with Stripe
    const { error } = await stripe.confirmCardPayment(clientSecret, {
      payment_method: {
        card: cardElement,
        billing_details: {
          name: cartSummary.billing_address?.name,
          email: cartSummary.user_email,
          address: cartSummary.billing_address
        }
      }
    });

    if (error) {
      onPaymentError(error.message);
    } else {
      onPaymentSuccess();
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="bg-white p-6 rounded-lg border">
        <h3 className="text-lg font-medium mb-4">Payment Information</h3>
        <CardElement
          options={{
            style: {
              base: {
                fontSize: '16px',
                color: '#424770',
                '::placeholder': {
                  color: '#aab7c4',
                },
              },
            },
          }}
        />
      </div>
      
      <button
        type="submit"
        disabled={!stripe}
        className="w-full bg-blue-600 text-white py-3 px-4 rounded-md hover:bg-blue-700 disabled:opacity-50"
      >
        Pay ${cartSummary.total_amount}
      </button>
    </form>
  );
};

const StripeCheckout = ({ cartSummary, onPaymentSuccess, onPaymentError }) => {
  return (
    <Elements stripe={stripePromise}>
      <CheckoutForm 
        cartSummary={cartSummary}
        onPaymentSuccess={onPaymentSuccess}
        onPaymentError={onPaymentError}
      />
    </Elements>
  );
};

export default StripeCheckout;
```

### B. Payment Intent API Endpoint
```elixir
# lib/shomp_web/controllers/api/payment_intent_controller.ex
defmodule ShompWeb.Api.PaymentIntentController do
  use ShompWeb, :controller
  
  alias Shomp.Payments
  alias Shomp.UnifiedCarts

  def create(conn, %{"cart_id" => cart_id, "platform_fee_enabled" => platform_fee_enabled}) do
    user = conn.assigns.current_scope.user
    cart = UnifiedCarts.get_unified_cart!(cart_id)
    
    # Verify cart belongs to user
    if cart.user_id != user.id do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Unauthorized"})
    else
      case Payments.create_payment_intent_with_splits(cart, platform_fee_enabled) do
        {:ok, payment_intent} ->
          json(conn, %{client_secret: payment_intent.client_secret})
        
        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: reason})
      end
    end
  end
end
```

## 3. Stripe Connect Payment Splitting

### A. Enhanced Payments Context
```elixir
# lib/shomp/payments.ex - Additional functions
def create_payment_intent_with_splits(cart, platform_fee_enabled) do
  cart_summary = UnifiedCarts.get_cart_summary(cart.id)
  
  # Calculate total amount
  total_amount = if platform_fee_enabled do
    Decimal.add(cart_summary.total_amount, cart_summary.platform_fee_amount)
  else
    cart_summary.total_amount
  end
  
  # Convert total amount to cents
  total_amount_cents = total_amount
  |> Decimal.mult(100)
  |> Decimal.round(0)
  |> Decimal.to_integer()
  
  # Create transfer destinations for each store
  transfer_destinations = 
    cart_summary.store_groups
    |> Enum.map(fn store_group ->
      store_amount_cents = store_group.total
      |> Decimal.mult(100)
      |> Decimal.round(0)
      |> Decimal.to_integer()
      
      %{
        destination: get_store_stripe_account_id(store_group.store.store_id),
        amount: store_amount_cents
      }
    end)
  
  # Add platform fee if enabled
  transfer_destinations = if platform_fee_enabled and cart_summary.platform_fee_amount > 0 do
    platform_fee_cents = cart_summary.platform_fee_amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()
    
    transfer_destinations ++ [%{
      destination: get_platform_stripe_account_id(),
      amount: platform_fee_cents
    }]
  else
    transfer_destinations
  end
  
  # Create payment intent with application fee
  application_fee_amount = if platform_fee_enabled do
    cart_summary.platform_fee_amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()
  else
    0
  end
  
  Stripe.PaymentIntent.create(%{
    amount: total_amount_cents,
    currency: "usd",
    application_fee_amount: application_fee_amount,
    transfer_data: %{
      destinations: transfer_destinations
    },
    metadata: %{
      cart_id: cart.id,
      user_id: cart.user_id,
      platform_fee_enabled: platform_fee_enabled
    }
  })
end

defp get_store_stripe_account_id(store_id) do
  case Stores.get_store_by_store_id(store_id) do
    nil -> nil
    store ->
      case Stores.get_store_kyc(store.id) do
        nil -> nil
        kyc -> kyc.stripe_account_id
      end
  end
end

defp get_platform_stripe_account_id do
  # Return the main Shomp Stripe account ID
  Application.get_env(:shomp, :stripe_platform_account_id)
end

def handle_payment_intent_succeeded(payment_intent) do
  cart_id = String.to_integer(payment_intent.metadata["cart_id"])
  user_id = String.to_integer(payment_intent.metadata["user_id"])
  platform_fee_enabled = payment_intent.metadata["platform_fee_enabled"] == "true"
  
  cart = UnifiedCarts.get_unified_cart!(cart_id)
  cart_summary = UnifiedCarts.get_cart_summary(cart_id)
  
  # Create payment records for each cart item
  payments = Enum.map(cart.unified_cart_items, fn cart_item ->
    create_payment(%{
      amount: Decimal.add(cart_item.store_amount, cart_item.platform_fee_amount),
      stripe_payment_id: payment_intent.id,
      product_id: cart_item.product_id,
      user_id: user_id,
      store_amount: cart_item.store_amount,
      platform_fee_amount: cart_item.platform_fee_amount
    })
  end)
  
  # Update store balances
  Enum.each(cart_summary.store_groups, fn store_group ->
    store_total = Enum.reduce(store_group.items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, item.store_amount)
    end)
    
    update_store_balance(store_group.store.store_id, store_total)
  end)
  
  # Create order for each store
  Enum.each(cart_summary.store_groups, fn store_group ->
    create_unified_order(cart, store_group, payment_intent.id, user_id)
  end)
  
  # Complete the unified cart
  UnifiedCarts.complete_cart(cart_id)
  
  {:ok, :payment_completed}
end
```

### B. Enhanced Payment Schema
```elixir
# Migration: add_payment_splitting_fields
defmodule Shomp.Repo.Migrations.AddPaymentSplittingFields do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :store_amount, :decimal, precision: 10, scale: 2
      add :platform_fee_amount, :decimal, precision: 10, scale: 2
      add :unified_cart_id, references(:unified_carts, on_delete: :nilify_all)
    end

    create index(:payments, [:unified_cart_id])
  end
end
```

## 4. Custom Checkout LiveView

### A. Checkout LiveView
```elixir
# lib/shomp_web/live/checkout_live/unified.ex
defmodule ShompWeb.CheckoutLive.Unified do
  use ShompWeb, :live_view

  alias Shomp.UnifiedCarts
  alias Shomp.Addresses

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    case UnifiedCarts.get_active_unified_cart(user.id) do
      nil ->
        {:ok, 
         socket
         |> put_flash(:error, "Your cart is empty")
         |> push_navigate(to: ~p"/cart")}
      
      cart ->
        cart_summary = UnifiedCarts.get_cart_summary(cart.id)
        billing_addresses = Addresses.list_user_addresses(user.id, "billing")
        shipping_addresses = Addresses.list_user_addresses(user.id, "shipping")
        
        socket = 
          socket
          |> assign(:cart, cart)
          |> assign(:cart_summary, cart_summary)
          |> assign(:billing_addresses, billing_addresses)
          |> assign(:shipping_addresses, shipping_addresses)
          |> assign(:selected_billing_address, List.first(billing_addresses))
          |> assign(:selected_shipping_address, List.first(shipping_addresses))
          |> assign(:platform_fee_enabled, cart.platform_fee_enabled)
          |> assign(:page_title, "Checkout")

        {:ok, socket}
    end
  end

  def handle_event("toggle_platform_fee", _params, socket) do
    cart = socket.assigns.cart
    new_fee_enabled = !socket.assigns.platform_fee_enabled
    
    case UnifiedCarts.update_platform_fee_setting(cart.id, new_fee_enabled) do
      {:ok, updated_cart} ->
        cart_summary = UnifiedCarts.get_cart_summary(updated_cart.id)
        
        {:noreply,
         socket
         |> assign(:cart, updated_cart)
         |> assign(:cart_summary, cart_summary)
         |> assign(:platform_fee_enabled, new_fee_enabled)}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update platform fee setting")}
    end
  end

  def handle_event("select_billing_address", %{"address_id" => address_id}, socket) do
    address = Addresses.get_address!(address_id)
    {:noreply, assign(socket, :selected_billing_address, address)}
  end

  def handle_event("select_shipping_address", %{"address_id" => address_id}, socket) do
    address = Addresses.get_address!(address_id)
    {:noreply, assign(socket, :selected_shipping_address, address)}
  end

  def handle_event("payment_success", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Payment successful! Your order has been placed.")
     |> push_navigate(to: ~p"/orders")}
  end

  def handle_event("payment_error", %{"error" => error}, socket) do
    {:noreply, put_flash(socket, :error, "Payment failed: #{error}")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Order Summary -->
          <div class="bg-white shadow-lg rounded-lg p-6">
            <h2 class="text-xl font-semibold mb-6">Order Summary</h2>
            
            <!-- Store Groups -->
            <div class="space-y-6">
              <%= for store_group <- @cart_summary.store_groups do %>
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium text-gray-900 mb-3">
                    <%= store_group.store.name %>
                  </h3>
                  
                  <div class="space-y-2">
                    <%= for item <- store_group.items do %>
                      <div class="flex justify-between items-center">
                        <div>
                          <span class="text-sm font-medium"><%= item.product.title %></span>
                          <span class="text-sm text-gray-500">x<%= item.quantity %></span>
                        </div>
                        <span class="text-sm font-medium">$<%= item.price %></span>
                      </div>
                    <% end %>
                  </div>
                  
                  <div class="mt-3 pt-3 border-t">
                    <div class="flex justify-between text-sm">
                      <span>Subtotal:</span>
                      <span>$<%= store_group.total %></span>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
            
            <!-- Platform Fee Toggle -->
            <div class="mt-6 p-4 bg-gray-50 rounded-lg">
              <label class="flex items-center">
                <input
                  type="checkbox"
                  checked={@platform_fee_enabled}
                  phx-click="toggle_platform_fee"
                  class="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
                />
                <span class="ml-2 text-sm text-gray-700">
                  Support Shomp with 5% donation ($<%= @cart_summary.platform_fee_amount %>)
                </span>
              </label>
            </div>
            
            <!-- Total -->
            <div class="mt-6 pt-6 border-t">
              <div class="flex justify-between text-lg font-semibold">
                <span>Total:</span>
                <span>$<%= @cart_summary.total_amount %></span>
              </div>
            </div>
          </div>
          
          <!-- Checkout Form -->
          <div class="space-y-6">
            <!-- Address Selection -->
            <div class="bg-white shadow-lg rounded-lg p-6">
              <h2 class="text-xl font-semibold mb-4">Billing Address</h2>
              <div class="space-y-2">
                <%= for address <- @billing_addresses do %>
                  <label class="flex items-center p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                    <input
                      type="radio"
                      name="billing_address"
                      value={address.id}
                      checked={@selected_billing_address.id == address.id}
                      phx-click="select_billing_address"
                      phx-value-address_id={address.id}
                      class="text-blue-600"
                    />
                    <div class="ml-3">
                      <div class="text-sm font-medium"><%= address.label %></div>
                      <div class="text-sm text-gray-500">
                        <%= address.street %>, <%= address.city %>, <%= address.state %> <%= address.zip_code %>
                      </div>
                    </div>
                  </label>
                <% end %>
              </div>
            </div>
            
            <!-- Payment Form -->
            <div class="bg-white shadow-lg rounded-lg p-6">
              <h2 class="text-xl font-semibold mb-4">Payment</h2>
              
              <div id="stripe-checkout" 
                   phx-hook="StripeCheckout"
                   data-cart-summary={Jason.encode!(@cart_summary)}
                   data-user-email={@current_scope.user.email}
                   data-billing-address={Jason.encode!(@selected_billing_address)}
                   data-payment-success-event="payment_success"
                   data-payment-error-event="payment_error">
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
```

### B. Stripe Elements Hook
```javascript
// assets/js/hooks/stripe_checkout.js
import StripeCheckout from '../stripe_elements.js';

const StripeCheckoutHook = {
  mounted() {
    const cartSummary = JSON.parse(this.el.dataset.cartSummary);
    const userEmail = this.el.dataset.userEmail;
    const billingAddress = JSON.parse(this.el.dataset.billingAddress);
    const paymentSuccessEvent = this.el.dataset.paymentSuccessEvent;
    const paymentErrorEvent = this.el.dataset.paymentErrorEvent;
    
    const checkoutProps = {
      cartSummary: {
        ...cartSummary,
        user_email: userEmail,
        billing_address: billingAddress
      },
      onPaymentSuccess: () => {
        this.pushEvent(paymentSuccessEvent);
      },
      onPaymentError: (error) => {
        this.pushEvent(paymentErrorEvent, { error });
      }
    };
    
    // Render Stripe Elements
    const root = ReactDOM.createRoot(this.el);
    root.render(React.createElement(StripeCheckout, checkoutProps));
  }
};

export default StripeCheckoutHook;
```

## 5. Enhanced Order Management

### A. Unified Order Schema
```elixir
# Migration: create_unified_orders
defmodule Shomp.Repo.Migrations.CreateUnifiedOrders do
  use Ecto.Migration

  def change do
    create table(:unified_orders) do
      add :immutable_id, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :unified_cart_id, references(:unified_carts, on_delete: :nilify_all)
      add :stripe_payment_intent_id, :string, null: false
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :status, :string, default: "pending"
      add :shipping_address_id, references(:addresses, on_delete: :nilify_all)
      add :billing_address_id, references(:addresses, on_delete: :nilify_all)
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:unified_orders, [:immutable_id])
    create index(:unified_orders, [:user_id])
    create index(:unified_orders, [:stripe_payment_intent_id])
  end
end

# Migration: create_unified_order_items
defmodule Shomp.Repo.Migrations.CreateUnifiedOrderItems do
  use Ecto.Migration

  def change do
    create table(:unified_order_items) do
      add :unified_order_id, references(:unified_orders, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :store_id, :string, null: false
      add :quantity, :integer, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :store_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      
      timestamps(type: :utc_datetime)
    end

    create index(:unified_order_items, [:unified_order_id])
    create index(:unified_order_items, [:store_id])
  end
end
```

### B. Store-Specific Order Creation
```elixir
# lib/shomp/unified_orders.ex
defmodule Shomp.UnifiedOrders do
  @moduledoc """
  The UnifiedOrders context for managing multi-store orders.
  """

  alias Shomp.UnifiedCarts
  alias Shomp.Orders

  def create_unified_order(cart, store_group, payment_intent_id, user_id) do
    # Create individual order for this store
    order_attrs = %{
      immutable_id: generate_order_id(),
      user_id: user_id,
      stripe_payment_id: payment_intent_id,
      total_amount: store_group.total,
      status: "pending",
      store_id: store_group.store.store_id
    }
    
    case Orders.create_order(order_attrs) do
      {:ok, order} ->
        # Create order items for this store
        Enum.each(store_group.items, fn cart_item ->
          Orders.create_order_item(%{
            order_id: order.id,
            product_id: cart_item.product_id,
            quantity: cart_item.quantity,
            price: cart_item.price
          })
        end)
        
        {:ok, order}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_order_id do
    "ORD_" <> :crypto.strong_rand_bytes(8) |> Base.encode64(padding: false)
  end
end
```

## 6. Frontend Dependencies

### A. Package.json Updates
```json
{
  "dependencies": {
    "@stripe/stripe-js": "^2.0.0",
    "@stripe/react-stripe-js": "^2.0.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
```

### B. Asset Pipeline Integration
```elixir
# config/config.exs
config :shomp, ShompWeb.Endpoint,
  # ... existing config ...
  live_view: [
    # ... existing config ...
    hooks: %{
      StripeCheckout: ShompWeb.Hooks.StripeCheckout
    }
  ]

# Add Stripe publishable key to assigns
config :shomp, ShompWeb.Endpoint,
  # ... existing config ...
  live_view: [
    # ... existing config ...
    signing_salt: "your_signing_salt"
  ]

# In your layout
defp put_stripe_config(socket) do
  socket
  |> assign(:stripe_publishable_key, Application.get_env(:shomp, :stripe_publishable_key))
end
```

## 7. Routes and Navigation

### A. Enhanced Router
```elixir
# lib/shomp_web/router.ex - Additional routes
scope "/", ShompWeb do
  # Unified checkout
  live "/checkout", CheckoutLive.Unified, :unified
  
  # API routes for Stripe
  scope "/api" do
    post "/payment-intents", Api.PaymentIntentController, :create
  end
end
```

## 8. Implementation Priority

### Phase 1: Core Infrastructure (Week 1-2)
1. Unified cart system with multi-store support
2. Enhanced payment schema with splitting fields
3. Stripe Elements integration setup
4. Basic custom checkout UI

### Phase 2: Payment Splitting (Week 3-4)
1. Stripe Connect payment splitting implementation
2. Platform fee calculation and collection
3. Payment intent creation with transfers
4. Webhook handling for split payments

### Phase 3: Enhanced UX (Week 5-6)
1. Address management integration
2. Platform fee toggle functionality
3. Order summary and confirmation
4. Error handling and validation

### Phase 4: Testing & Optimization (Week 7-8)
1. Comprehensive testing suite
2. Performance optimization
3. Security audit
4. Documentation and deployment

## 9. Testing Strategy

### A. Unit Tests
- Unified cart calculations
- Payment splitting logic
- Platform fee calculations
- Address validation

### B. Integration Tests
- End-to-end checkout flow
- Stripe Elements integration
- Payment intent creation
- Webhook handling

### C. E2E Tests
- Multi-store checkout flow
- Platform fee toggle
- Payment success/failure scenarios
- Order creation and confirmation

## 10. Security Considerations

### A. Payment Security
- PCI compliance through Stripe Elements
- Secure payment intent creation
- Webhook signature verification
- Input validation and sanitization

### B. Data Protection
- Encrypted sensitive data storage
- Secure API endpoints
- User authentication and authorization
- Audit logging for financial transactions

## 11. Monitoring and Analytics

### A. Key Metrics
- Checkout completion rate
- Platform fee collection rate
- Payment success rate
- Average order value
- Multi-store order frequency

### B. Alerts
- Payment processing failures
- High checkout abandonment rates
- Stripe API errors
- Webhook processing failures

This comprehensive plan provides a robust foundation for implementing custom checkout with Stripe Elements and Connect payment splitting, while maintaining the existing Shomp infrastructure and adding the requested platform donation feature.
