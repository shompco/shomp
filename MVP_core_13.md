# Shomp MVP Core 13 - Shippo Integration & SMS Notifications

## Overview
This MVP adds shipping integration for physical products and SMS notifications for new physical orders. This enables sellers to fulfill physical orders efficiently and keeps customers informed about their order status via SMS.

## Core Concept
- **Shippo Integration**: Automatically create shipping labels for physical orders
- **SMS Notifications**: Send SMS alerts for new physical orders to both sellers and buyers
- **Order Tracking**: Provide tracking information to customers
- **Physical Order Workflow**: Complete fulfillment process for physical products

## 1. Shippo Integration

### Dependencies
Add Shippo SDK to `mix.exs`:
```elixir
defp deps do
  [
    # ... existing deps ...
    {:shippo, "~> 1.0"},
    {:message_bird, "~> 0.1"}  # For SMS notifications
  ]
end
```

### Configuration
Add to `config/config.exs`:
```elixir
config :shomp, Shomp.Shipping,
  shippo_api_key: System.get_env("SHIPPO_API_KEY"),
  shippo_base_url: "https://api.goshippo.com/v1"

config :shomp, Shomp.SMS,
  messagebird_api_key: System.get_env("MESSAGEBIRD_API_KEY"),
  messagebird_originator: System.get_env("MESSAGEBIRD_ORIGINATOR")
```

### Database Changes
```elixir
# Migration: Add shipping fields to orders
defmodule Shomp.Repo.Migrations.AddShippingToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :shipping_address, :map
      add :shipping_method, :string
      add :tracking_number, :string
      add :shippo_transaction_id, :string
      add :shipping_status, :string, default: "pending"
      add :shipping_cost, :decimal, precision: 10, scale: 2
    end

    create index(:orders, [:shipping_status])
    create index(:orders, [:tracking_number])
  end
end

# Migration: Add phone number to users
defmodule Shomp.Repo.Migrations.AddPhoneToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :phone_number, :string
    end

    create index(:users, [:phone_number])
  end
end
```

### Shipping Context
```elixir
defmodule Shomp.Shipping do
  @moduledoc """
  Handles shipping integration with Shippo.
  """

  alias Shomp.Orders.Order
  alias Shomp.Products.Product
  alias Shomp.Repo

  @doc """
  Creates a shipping label for a physical order.
  """
  def create_shipping_label(order) do
    with {:ok, order} <- validate_physical_order(order),
         {:ok, shipment} <- create_shippo_shipment(order),
         {:ok, transaction} <- purchase_shippo_label(shipment) do
      
      # Update order with shipping information
      order
      |> Order.changeset(%{
        tracking_number: transaction.tracking_number,
        shippo_transaction_id: transaction.object_id,
        shipping_status: "shipped",
        shipping_cost: transaction.rate.amount
      })
      |> Repo.update()
    end
  end

  @doc """
  Gets tracking information for an order.
  """
  def get_tracking_info(order) do
    if order.shippo_transaction_id do
      Shippo.Transaction.retrieve(order.shippo_transaction_id)
    else
      {:error, :no_tracking}
    end
  end

  @doc """
  Validates that an order contains physical products.
  """
  defp validate_physical_order(order) do
    physical_items = Enum.filter(order.order_items, &(&1.product.type == "physical"))
    
    if Enum.empty?(physical_items) do
      {:error, :no_physical_items}
    else
      {:ok, order}
    end
  end

  @doc """
  Creates a shipment in Shippo.
  """
  defp create_shippo_shipment(order) do
    shipment_data = %{
      address_from: get_seller_address(order),
      address_to: order.shipping_address,
      parcels: build_parcels(order),
      async: false
    }

    case Shippo.Shipment.create(shipment_data) do
      {:ok, shipment} -> {:ok, shipment}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Purchases a shipping label from Shippo.
  """
  defp purchase_shippo_label(shipment) do
    # Get the cheapest rate
    rate = Enum.min_by(shipment.rates, & &1.amount)
    
    transaction_data = %{
      rate: rate.object_id,
      label_file_type: "PDF",
      async: false
    }

    case Shippo.Transaction.create(transaction_data) do
      {:ok, transaction} -> {:ok, transaction}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets seller's shipping address from their store.
  """
  defp get_seller_address(order) do
    # This would come from the seller's store settings
    %{
      name: "Seller Name",
      street1: "123 Main St",
      city: "San Francisco",
      state: "CA",
      zip: "94105",
      country: "US"
    }
  end

  @doc """
  Builds parcel information for Shippo.
  """
  defp build_parcels(order) do
    # Calculate total weight and dimensions
    total_weight = Enum.reduce(order.order_items, 0, fn item, acc ->
      weight = item.product.weight || 1.0  # Default 1 lb
      acc + (weight * item.quantity)
    end)

    [%{
      length: "6",
      width: "4", 
      height: "2",
      weight: "#{total_weight}",
      mass_unit: "lb",
      distance_unit: "in"
    }]
  end
end
```

## 2. SMS Notifications

### SMS Context
```elixir
defmodule Shomp.SMS do
  @moduledoc """
  Handles SMS notifications using Twilio.
  """

  alias Shomp.Orders.Order
  alias Shomp.Accounts.User
  alias Shomp.Repo

  @doc """
  Sends SMS notification for new physical order.
  """
  def send_order_notification(order) do
    with {:ok, seller} <- get_seller(order),
         {:ok, buyer} <- get_buyer(order) do
      
      # Send SMS to seller
      send_seller_notification(seller, order)
      
      # Send SMS to buyer if they have phone number
      if buyer.phone_number do
        send_buyer_notification(buyer, order)
      end
      
      :ok
    end
  end

  @doc """
  Sends shipping confirmation SMS.
  """
  def send_shipping_confirmation(order) do
    with {:ok, buyer} <- get_buyer(order) do
      if buyer.phone_number do
        message = """
        Your order ##{order.id} has been shipped! 
        Tracking: #{order.tracking_number}
        Track at: #{get_tracking_url(order.tracking_number)}
        """
        
        send_sms(buyer.phone_number, message)
      end
    end
  end

  @doc """
  Sends delivery confirmation SMS.
  """
  def send_delivery_confirmation(order) do
    with {:ok, buyer} <- get_buyer(order) do
      if buyer.phone_number do
        message = """
        Your order ##{order.id} has been delivered! 
        Thanks for shopping with us.
        """
        
        send_sms(buyer.phone_number, message)
      end
    end
  end

  @doc """
  Sends SMS to seller about new physical order.
  """
  defp send_seller_notification(seller, order) do
    if seller.phone_number do
      message = """
        New physical order ##{order.id} received!
        Customer: #{order.buyer_name}
        Total: $#{order.total_amount}
        Items: #{get_item_summary(order)}
        """
      
      send_sms(seller.phone_number, message)
    end
  end

  @doc """
  Sends SMS to buyer about new order.
  """
  defp send_buyer_notification(buyer, order) do
    message = """
      Order ##{order.id} confirmed!
      Total: $#{order.total_amount}
      Items: #{get_item_summary(order)}
      We'll notify you when it ships.
      """
    
    send_sms(buyer.phone_number, message)
  end

  @doc """
  Sends SMS using MessageBird.
  """
  defp send_sms(phone_number, message) do
    MessageBird.send_message(%{
      originator: Application.get_env(:shomp, :messagebird_originator),
      recipients: [phone_number],
      body: message
    })
  end

  @doc """
  Gets seller from order.
  """
  defp get_seller(order) do
    # Get seller from first order item's product
    order_item = List.first(order.order_items)
    if order_item do
      product = Repo.preload(order_item, :product).product
      store = Repo.preload(product, :store).store
      user = Repo.preload(store, :user).user
      {:ok, user}
    else
      {:error, :no_seller}
    end
  end

  @doc """
  Gets buyer from order.
  """
  defp get_buyer(order) do
    user = Repo.preload(order, :user).user
    {:ok, user}
  end

  @doc """
  Gets item summary for SMS.
  """
  defp get_item_summary(order) do
    order.order_items
    |> Enum.map(fn item -> "#{item.quantity}x #{item.product.title}" end)
    |> Enum.join(", ")
  end

  @doc """
  Gets tracking URL for carrier.
  """
  defp get_tracking_url(tracking_number) do
    # This would be determined by the carrier
    "https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=#{tracking_number}"
  end
end
```

## 3. Order Processing Updates

### Update Orders Context
```elixir
defmodule Shomp.Orders do
  # ... existing code ...

  @doc """
  Processes a physical order after payment.
  """
  def process_physical_order(order) do
    with {:ok, order} <- mark_order_as_paid(order),
         :ok <- send_order_notifications(order) do
      {:ok, order}
    end
  end

  @doc """
  Ships a physical order.
  """
  def ship_order(order) do
    with {:ok, order} <- Shomp.Shipping.create_shipping_label(order),
         :ok <- Shomp.SMS.send_shipping_confirmation(order) do
      {:ok, order}
    end
  end

  @doc """
  Marks order as delivered.
  """
  def mark_delivered(order) do
    order
    |> Order.changeset(%{shipping_status: "delivered"})
    |> Repo.update()
    |> case do
      {:ok, order} -> 
        Shomp.SMS.send_delivery_confirmation(order)
        {:ok, order}
      error -> error
    end
  end

  @doc """
  Sends order notifications.
  """
  defp send_order_notifications(order) do
    # Send email notification (existing)
    send_order_email_notification(order)
    
    # Send SMS notification for physical orders
    if has_physical_items?(order) do
      Shomp.SMS.send_order_notification(order)
    end
    
    :ok
  end

  @doc """
  Checks if order has physical items.
  """
  defp has_physical_items?(order) do
    order.order_items
    |> Enum.any?(&(&1.product.type == "physical"))
  end
end
```

## 4. UI Updates

### Order Management for Sellers
```elixir
defmodule ShompWeb.SellerOrderLive.Show do
  # ... existing code ...

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <!-- Order Header -->
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-3xl font-bold text-base-content">Order ##{@order.id}</h1>
            <p class="text-base-content/70 mt-1">
              Placed on <%= Calendar.strftime(@order.inserted_at, "%B %d, %Y at %I:%M %p") %>
            </p>
          </div>
          <div class="flex space-x-3">
            <%= if @order.shipping_status == "pending" do %>
              <button
                phx-click="ship_order"
                class="btn btn-primary"
              >
                Create Shipping Label
              </button>
            <% end %>
            <%= if @order.shipping_status == "shipped" do %>
              <button
                phx-click="mark_delivered"
                class="btn btn-success"
              >
                Mark as Delivered
              </button>
            <% end %>
          </div>
        </div>

        <!-- Order Status -->
        <div class="card bg-base-100 shadow-md mb-6">
          <div class="card-body">
            <h2 class="card-title">Order Status</h2>
            <div class="flex items-center space-x-4">
              <div class={if @order.payment_status == "paid", do: "badge badge-success", else: "badge badge-warning"}>
                Payment: <%= String.capitalize(@order.payment_status) %>
              </div>
              <div class={get_shipping_status_class(@order.shipping_status)}>
                Shipping: <%= String.capitalize(@order.shipping_status) %>
              </div>
            </div>
          </div>
        </div>

        <!-- Shipping Information -->
        <%= if @order.shipping_address do %>
          <div class="card bg-base-100 shadow-md mb-6">
            <div class="card-body">
              <h2 class="card-title">Shipping Address</h2>
              <div class="text-base-content/80">
                <p><%= @order.shipping_address["name"] %></p>
                <p><%= @order.shipping_address["street1"] %></p>
                <%= if @order.shipping_address["street2"] do %>
                  <p><%= @order.shipping_address["street2"] %></p>
                <% end %>
                <p><%= @order.shipping_address["city"] %>, <%= @order.shipping_address["state"] %> <%= @order.shipping_address["zip"] %></p>
                <p><%= @order.shipping_address["country"] %></p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Tracking Information -->
        <%= if @order.tracking_number do %>
          <div class="card bg-base-100 shadow-md mb-6">
            <div class="card-body">
              <h2 class="card-title">Tracking Information</h2>
              <div class="flex items-center space-x-4">
                <div>
                  <p class="font-semibold">Tracking Number:</p>
                  <p class="font-mono text-lg"><%= @order.tracking_number %></p>
                </div>
                <div>
                  <a 
                    href={get_tracking_url(@order.tracking_number)}
                    target="_blank"
                    class="btn btn-outline btn-sm"
                  >
                    Track Package
                  </a>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Order Items -->
        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h2 class="card-title">Order Items</h2>
            <div class="space-y-4">
              <%= for item <- @order.order_items do %>
                <div class="flex items-center space-x-4 p-4 border border-base-300 rounded-lg">
                  <div class="w-16 h-16 bg-base-200 rounded-lg flex items-center justify-center">
                    <%= if get_product_image(item.product) do %>
                      <img
                        src={get_product_image(item.product)}
                        alt={item.product.title}
                        class="w-full h-full object-cover rounded-lg"
                      />
                    <% else %>
                      <svg class="w-8 h-8 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    <% end %>
                  </div>
                  <div class="flex-1">
                    <h3 class="font-semibold text-base-content"><%= item.product.title %></h3>
                    <p class="text-base-content/70"><%= item.product.type |> String.capitalize() %></p>
                    <p class="text-base-content/70">Quantity: <%= item.quantity %></p>
                  </div>
                  <div class="text-right">
                    <p class="font-semibold text-lg">$<%= item.price %></p>
                    <p class="text-base-content/70">Total: $<%= item.price * item.quantity %></p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("ship_order", _params, socket) do
    case Shomp.Orders.ship_order(socket.assigns.order) do
      {:ok, order} ->
        {:noreply, assign(socket, order: order) |> put_flash(:info, "Order shipped successfully!")}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to ship order: #{inspect(reason)}")}
    end
  end

  def handle_event("mark_delivered", _params, socket) do
    case Shomp.Orders.mark_delivered(socket.assigns.order) do
      {:ok, order} ->
        {:noreply, assign(socket, order: order) |> put_flash(:info, "Order marked as delivered!")}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to mark as delivered: #{inspect(reason)}")}
    end
  end

  defp get_shipping_status_class(status) do
    case status do
      "pending" -> "badge badge-warning"
      "shipped" -> "badge badge-info"
      "delivered" -> "badge badge-success"
      _ -> "badge badge-neutral"
    end
  end

  defp get_tracking_url(tracking_number) do
    "https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=#{tracking_number}"
  end
end
```

### Customer Order Tracking
```elixir
defmodule ShompWeb.OrderLive.Show do
  # ... existing code ...

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <!-- Order Header -->
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-base-content">Order ##{@order.id}</h1>
          <p class="text-base-content/70 mt-1">
            Placed on <%= Calendar.strftime(@order.inserted_at, "%B %d, %Y at %I:%M %p") %>
          </p>
        </div>

        <!-- Order Status -->
        <div class="card bg-base-100 shadow-md mb-6">
          <div class="card-body">
            <h2 class="card-title">Order Status</h2>
            <div class="flex items-center space-x-4">
              <div class={if @order.payment_status == "paid", do: "badge badge-success", else: "badge badge-warning"}>
                Payment: <%= String.capitalize(@order.payment_status) %>
              </div>
              <div class={get_shipping_status_class(@order.shipping_status)}>
                Shipping: <%= String.capitalize(@order.shipping_status) %>
              </div>
            </div>
          </div>
        </div>

        <!-- Tracking Information -->
        <%= if @order.tracking_number do %>
          <div class="card bg-base-100 shadow-md mb-6">
            <div class="card-body">
              <h2 class="card-title">Tracking Information</h2>
              <div class="flex items-center space-x-4">
                <div>
                  <p class="font-semibold">Tracking Number:</p>
                  <p class="font-mono text-lg"><%= @order.tracking_number %></p>
                </div>
                <div>
                  <a 
                    href={get_tracking_url(@order.tracking_number)}
                    target="_blank"
                    class="btn btn-primary btn-sm"
                  >
                    Track Package
                  </a>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Order Items -->
        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h2 class="card-title">Order Items</h2>
            <div class="space-y-4">
              <%= for item <- @order.order_items do %>
                <div class="flex items-center space-x-4 p-4 border border-base-300 rounded-lg">
                  <div class="w-16 h-16 bg-base-200 rounded-lg flex items-center justify-center">
                    <%= if get_product_image(item.product) do %>
                      <img
                        src={get_product_image(item.product)}
                        alt={item.product.title}
                        class="w-full h-full object-cover rounded-lg"
                      />
                    <% else %>
                      <svg class="w-8 h-8 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    <% end %>
                  </div>
                  <div class="flex-1">
                    <h3 class="font-semibold text-base-content"><%= item.product.title %></h3>
                    <p class="text-base-content/70"><%= item.product.type |> String.capitalize() %></p>
                    <p class="text-base-content/70">Quantity: <%= item.quantity %></p>
                  </div>
                  <div class="text-right">
                    <p class="font-semibold text-lg">$<%= item.price %></p>
                    <p class="text-base-content/70">Total: $<%= item.price * item.quantity %></p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp get_shipping_status_class(status) do
    case status do
      "pending" -> "badge badge-warning"
      "shipped" -> "badge badge-info"
      "delivered" -> "badge badge-success"
      _ -> "badge badge-neutral"
    end
  end

  defp get_tracking_url(tracking_number) do
    "https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=#{tracking_number}"
  end
end
```

## 5. User Profile Updates

### Add Phone Number to User Profile
```elixir
defmodule ShompWeb.ProfileLive.Edit do
  # ... existing code ...

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <h1 class="text-3xl font-bold text-base-content mb-8">Edit Profile</h1>
        
        <.form for={@form} phx-submit="save" class="space-y-6">
          <!-- Name -->
          <div class="form-control">
            <label class="label">
              <span class="label-text">Name</span>
            </label>
            <.input
              field={@form[:name]}
              type="text"
              placeholder="Your full name"
              class="input input-bordered w-full"
            />
          </div>

          <!-- Username -->
          <div class="form-control">
            <label class="label">
              <span class="label-text">Username</span>
            </label>
            <.input
              field={@form[:username]}
              type="text"
              placeholder="your-username"
              class="input input-bordered w-full"
            />
            <label class="label">
              <span class="label-text-alt">This will be your store URL: shomp.co/your-username</span>
            </label>
          </div>

          <!-- Phone Number -->
          <div class="form-control">
            <label class="label">
              <span class="label-text">Phone Number</span>
            </label>
            <.input
              field={@form[:phone_number]}
              type="tel"
              placeholder="+1 (555) 123-4567"
              class="input input-bordered w-full"
            />
            <label class="label">
              <span class="label-text-alt">For SMS notifications about your orders</span>
            </label>
          </div>

          <!-- Submit Button -->
          <div class="form-control">
            <button type="submit" class="btn btn-primary">Save Changes</button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
```

## 6. Environment Variables

Add to `.env` file:
```bash
# Shippo Configuration
SHIPPO_API_KEY=your_shippo_api_key_here

# MessageBird Configuration
MESSAGEBIRD_API_KEY=your_messagebird_api_key_here
MESSAGEBIRD_ORIGINATOR=Shomp
```

## 7. Implementation Benefits

### For Sellers
- **Automated Shipping**: Create shipping labels with one click
- **Order Notifications**: Get SMS alerts for new physical orders
- **Professional Fulfillment**: Complete shipping workflow
- **Tracking Management**: Easy order status updates

### For Customers
- **Order Tracking**: Real-time tracking information
- **SMS Updates**: Get notified about order status changes
- **Professional Experience**: Complete order fulfillment process
- **Peace of Mind**: Know when orders are shipped and delivered

### For Platform
- **Complete Physical Product Support**: Full e-commerce functionality
- **Professional Image**: Automated shipping and notifications
- **Reduced Support**: Fewer "where's my order" inquiries
- **Scalable Fulfillment**: Automated processes that scale

## 8. Implementation Notes

### Shippo Integration
- **API Key Required**: Need to sign up for Shippo account
- **Carrier Support**: Supports USPS, UPS, FedEx, DHL
- **Rate Shopping**: Automatically finds cheapest shipping option
- **Label Generation**: Creates printable PDF labels

### SMS Notifications
- **MessageBird Integration**: Reliable SMS delivery with better pricing
- **Phone Number Collection**: Users need to provide phone numbers
- **Opt-in Required**: Follow SMS compliance best practices
- **Cost Management**: SMS costs per message (typically 20-30% cheaper than Twilio)

### Order Workflow
1. **Order Placed**: Customer places physical order
2. **SMS Sent**: Both seller and buyer get SMS notifications
3. **Seller Ships**: Seller creates shipping label via Shippo
4. **Tracking Sent**: Customer gets tracking information via SMS
5. **Delivery Confirmed**: Seller marks as delivered, customer gets SMS

This MVP completes the physical product fulfillment workflow and provides professional order management capabilities for sellers.
