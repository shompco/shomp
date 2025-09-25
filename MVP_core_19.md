# Shomp MVP Core 19 - Final Release Features

## Overview
This MVP covers the final features needed to complete the initial release, including third-party integrations, audience management, shopping cart enhancements, and clothing inventory support.

## Core Features

### 1. Shippo Integration Testing & Implementation
- **Real API Integration**: Replace mock shipping functions with actual Shippo API
- **Shipping Label Generation**: Create printable PDF labels for physical orders
- **Rate Calculation**: Real-time shipping cost calculation during checkout
- **Tracking Integration**: Automatic tracking updates via webhooks
- **Error Handling**: Robust error handling for API failures

### 2. MessageBird SMS Integration
- **SMS Notifications**: Send SMS alerts for new physical orders
- **Order Status Updates**: SMS notifications for shipping and delivery
- **Seller Alerts**: Immediate SMS to sellers for new physical product sales
- **Delivery Confirmation**: SMS when orders are delivered
- **Error Handling**: Handle SMS delivery failures gracefully

### 3. Beehiiv Newsletter Integration
- **API Integration**: Connect to Beehiiv API for newsletter management
- **Store Page Signup**: Newsletter signup forms on individual store pages
- **Email Collection**: Secure email collection and validation
- **Subscription Management**: Handle subscribe/unsubscribe events
- **Audience Building**: Help creators build their email lists

### 4. Audience Management System
- **Creator Email Lists**: Each creator can build their own email audience
- **Profile Integration**: Add audience management to user profile pages
- **Email Tracking**: Track email signups per creator/store
- **Audience Analytics**: Basic analytics for email list growth
- **Opt-in Management**: Proper consent and opt-out handling

### 5. Shopping Cart Support (Optional)
- **Multi-Store Cart**: Allow adding products from different stores to one cart
- **Cart Persistence**: Save cart across browser sessions
- **Cart Management**: Add/remove items, update quantities
- **Checkout Integration**: Unified checkout for multi-store purchases

### 6. Clothing Inventory & Size Options
- **Size Variants**: Add size options (XS, S, M, L, XL, XXL, etc.)
- **Inventory Tracking**: Track inventory per size variant
- **Size Selection**: Customer size selection during purchase
- **Inventory Management**: Seller inventory management interface
- **Low Stock Alerts**: Notifications when inventory is low

## Implementation Tasks

### Phase 1: Third-Party Integrations (Week 1-2)

#### 1.1 Shippo Integration
```elixir
# Add to mix.exs
defp deps do
  [
    # ... existing deps ...
    {:shippo, "~> 1.0"}
  ]
end

# Configuration
config :shomp, Shomp.Shipping,
  shippo_api_key: System.get_env("SHIPPO_API_KEY"),
  shippo_base_url: "https://api.goshippo.com/v1"

# Real Shippo integration
defmodule Shomp.Shipping do
  def create_shipping_label(order) do
    with {:ok, shipment} <- create_shippo_shipment(order),
         {:ok, transaction} <- purchase_shippo_label(shipment) do
      
      # Update order with real tracking info
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

  def calculate_shipping_rates(address_from, address_to, parcels) do
    shipment_data = %{
      address_from: address_from,
      address_to: address_to,
      parcels: parcels,
      async: false
    }

    case Shippo.Shipment.create(shipment_data) do
      {:ok, shipment} -> {:ok, shipment.rates}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### 1.2 MessageBird SMS Integration
```elixir
# Add to mix.exs
defp deps do
  [
    # ... existing deps ...
    {:message_bird, "~> 0.1"}
  ]
end

# Configuration
config :shomp, Shomp.SMS,
  messagebird_api_key: System.get_env("MESSAGEBIRD_API_KEY"),
  messagebird_originator: System.get_env("MESSAGEBIRD_ORIGINATOR")

# SMS Context
defmodule Shomp.SMS do
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

  defp send_sms(phone_number, message) do
    MessageBird.send_message(%{
      originator: Application.get_env(:shomp, :messagebird_originator),
      recipients: [phone_number],
      body: message
    })
  end
end
```

#### 1.3 Beehiiv Integration
```elixir
# Add to mix.exs
defp deps do
  [
    # ... existing deps ...
    {:beehiiv, "~> 0.1"}  # Custom hex package or HTTP client
  ]
end

# Configuration
config :shomp, Shomp.Newsletter,
  beehiiv_api_key: System.get_env("BEEHIIV_API_KEY"),
  beehiiv_base_url: "https://api.beehiiv.com/v1"

# Newsletter Context
defmodule Shomp.Newsletter do
  def subscribe_email(email, store_id) do
    with {:ok, subscriber} <- create_beehiiv_subscriber(email, store_id),
         {:ok, _} <- store_subscription_locally(email, store_id, subscriber.id) do
      {:ok, subscriber}
    end
  end

  defp create_beehiiv_subscriber(email, store_id) do
    # Beehiiv API call to create subscriber
    # This would use HTTP client to call Beehiiv API
  end
end
```

### Phase 2: Audience Management (Week 3)

#### 2.1 Database Schema
```elixir
# Migration: create_newsletter_subscriptions
defmodule Shomp.Repo.Migrations.CreateNewsletterSubscriptions do
  use Ecto.Migration

  def change do
    create table(:newsletter_subscriptions) do
      add :email, :string, null: false
      add :user_id, references(:users, type: :bigserial), null: true
      add :store_id, references(:stores, type: :string), null: true
      add :beehiiv_subscriber_id, :string
      add :status, :string, default: "active" # active, unsubscribed, bounced
      add :subscribed_at, :utc_datetime, null: false
      add :unsubscribed_at, :utc_datetime, null: true
      
      timestamps()
    end

    create unique_index(:newsletter_subscriptions, [:email, :store_id])
    create index(:newsletter_subscriptions, [:user_id])
    create index(:newsletter_subscriptions, [:store_id])
    create index(:newsletter_subscriptions, [:status])
  end
end
```

#### 2.2 Store Page Newsletter Signup
```elixir
defmodule ShompWeb.Components.NewsletterSignup do
  use ShompWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-md">
      <div class="card-body">
        <h3 class="card-title">Stay Updated</h3>
        <p class="text-base-content/70">
          Subscribe to <%= @store.name %>'s newsletter for new products and updates.
        </p>
        
        <.form for={@form} phx-submit="subscribe" phx-target={@myself}>
          <div class="form-control">
            <input
              type="email"
              field={@form[:email]}
              placeholder="Enter your email"
              class="input input-bordered w-full"
              required
            />
          </div>
          <div class="form-control mt-4">
            <button type="submit" class="btn btn-primary w-full">
              Subscribe
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("subscribe", %{"email" => email}, socket) do
    case Shomp.Newsletter.subscribe_email(email, socket.assigns.store.id) do
      {:ok, _subscriber} ->
        {:noreply, put_flash(socket, :info, "Successfully subscribed!")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to subscribe. Please try again.")}
    end
  end
end
```

### Phase 3: Shopping Cart Support (Week 4)

#### 3.1 Multi-Store Cart Schema
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
      add :store_id, :string, null: false
      add :quantity, :integer, default: 1
      add :price, :decimal, precision: 10, scale: 2
      add :size_variant, :string, null: true
      
      timestamps(type: :utc_datetime)
    end

    create index(:unified_cart_items, [:unified_cart_id])
    create index(:unified_cart_items, [:store_id])
    create unique_index(:unified_cart_items, [:unified_cart_id, :product_id, :size_variant])
  end
end
```

#### 3.2 Unified Cart Context
```elixir
defmodule Shomp.UnifiedCarts do
  def add_to_cart(user_id, product_id, quantity \\ 1, size_variant \\ nil) do
    with {:ok, cart} <- get_or_create_cart(user_id),
         {:ok, cart_item} <- create_or_update_cart_item(cart, product_id, quantity, size_variant) do
      recalculate_cart_totals(cart.id)
      {:ok, cart_item}
    end
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
          Decimal.add(acc, Decimal.mult(item.price, item.quantity))
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

### Phase 4: Clothing Inventory & Size Options (Week 5)

#### 4.1 Size Variants Schema
```elixir
# Migration: create_product_variants
defmodule Shomp.Repo.Migrations.CreateProductVariants do
  use Ecto.Migration

  def change do
    create table(:product_variants) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :variant_name, :string, null: false # "Size", "Color", etc.
      add :variant_value, :string, null: false # "M", "Red", etc.
      add :price_modifier, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :inventory_count, :integer, default: 0
      add :sku, :string
      add :is_active, :boolean, default: true
      
      timestamps(type: :utc_datetime)
    end

    create index(:product_variants, [:product_id])
    create index(:product_variants, [:variant_name])
    create unique_index(:product_variants, [:product_id, :variant_name, :variant_value])
  end
end
```

#### 4.2 Size Selection Component
```elixir
defmodule ShompWeb.Components.SizeSelector do
  use ShompWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="form-control">
      <label class="label">
        <span class="label-text font-medium">Size</span>
      </label>
      <div class="grid grid-cols-4 gap-2">
        <%= for variant <- @variants do %>
          <button
            type="button"
            class={[
              "btn btn-outline",
              if(@selected_size == variant.variant_value, do: "btn-primary", else: "btn-outline"),
              if(variant.inventory_count == 0, do: "btn-disabled")
            ]}
            phx-click="select_size"
            phx-value-size={variant.variant_value}
            phx-target={@myself}
            disabled={variant.inventory_count == 0}
          >
            <%= variant.variant_value %>
            <%= if variant.inventory_count == 0 do %>
              <span class="text-xs text-error">(Sold Out)</span>
            <% end %>
          </button>
        <% end %>
      </div>
      <%= if @selected_size do %>
        <div class="text-sm text-base-content/70 mt-2">
          <%= get_inventory_text(@selected_size, @variants) %>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("select_size", %{"size" => size}, socket) do
    {:noreply, assign(socket, selected_size: size)}
  end

  defp get_inventory_text(size, variants) do
    variant = Enum.find(variants, &(&1.variant_value == size))
    if variant do
      if variant.inventory_count > 0 do
        "#{variant.inventory_count} in stock"
      else
        "Out of stock"
      end
    else
      ""
    end
  end
end
```

#### 4.3 Inventory Management Interface
```elixir
defmodule ShompWeb.ProductLive.Variants do
  use ShompWeb, :live_view

  alias Shomp.Products

  def mount(%{"product_id" => product_id}, _session, socket) do
    product = Products.get_product!(product_id)
    variants = Products.get_product_variants(product_id)
    
    {:ok, assign(socket, 
      product: product,
      variants: variants,
      new_variant: %{variant_name: "Size", variant_value: "", inventory_count: 0}
    )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-3xl font-bold text-base-content">
            Manage Variants - <%= @product.title %>
          </h1>
          <.link
            navigate={~p"/dashboard/products/#{@product.id}"}
            class="btn btn-outline"
          >
            Back to Product
          </.link>
        </div>

        <!-- Add New Variant -->
        <div class="card bg-base-100 shadow-md mb-8">
          <div class="card-body">
            <h3 class="card-title">Add New Variant</h3>
            
            <.form for={@new_variant} phx-submit="add_variant">
              <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Variant Name</span>
                  </label>
                  <select name="variant_name" class="select select-bordered">
                    <option value="Size">Size</option>
                    <option value="Color">Color</option>
                    <option value="Style">Style</option>
                  </select>
                </div>
                
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Variant Value</span>
                  </label>
                  <input
                    type="text"
                    name="variant_value"
                    placeholder="M, Red, etc."
                    class="input input-bordered"
                    required
                  />
                </div>
                
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Inventory</span>
                  </label>
                  <input
                    type="number"
                    name="inventory_count"
                    placeholder="0"
                    class="input input-bordered"
                    min="0"
                    required
                  />
                </div>
                
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Action</span>
                  </label>
                  <button type="submit" class="btn btn-primary">
                    Add Variant
                  </button>
                </div>
              </div>
            </.form>
          </div>
        </div>

        <!-- Existing Variants -->
        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h3 class="card-title">Current Variants</h3>
            
            <%= if Enum.empty?(@variants) do %>
              <div class="text-center py-8">
                <p class="text-base-content/70">No variants added yet.</p>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th>Variant Name</th>
                      <th>Value</th>
                      <th>Inventory</th>
                      <th>Price Modifier</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for variant <- @variants do %>
                      <tr>
                        <td><%= variant.variant_name %></td>
                        <td><%= variant.variant_value %></td>
                        <td>
                          <div class="flex items-center space-x-2">
                            <span><%= variant.inventory_count %></span>
                            <%= if variant.inventory_count == 0 do %>
                              <span class="badge badge-error badge-sm">Out of Stock</span>
                            <% else %>
                              <span class="badge badge-success badge-sm">In Stock</span>
                            <% end %>
                          </div>
                        </td>
                        <td>
                          <%= if variant.price_modifier > 0 do %>
                            +$<%= variant.price_modifier %>
                          <% else %>
                            $<%= variant.price_modifier %>
                          <% end %>
                        </td>
                        <td>
                          <div class="flex space-x-2">
                            <button
                              class="btn btn-outline btn-sm"
                              phx-click="edit_variant"
                              phx-value-variant_id={variant.id}
                            >
                              Edit
                            </button>
                            <button
                              class="btn btn-error btn-sm"
                              phx-click="delete_variant"
                              phx-value-variant_id={variant.id}
                            >
                              Delete
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("add_variant", %{"variant_name" => name, "variant_value" => value, "inventory_count" => count}, socket) do
    variant_attrs = %{
      product_id: socket.assigns.product.id,
      variant_name: name,
      variant_value: value,
      inventory_count: String.to_integer(count),
      price_modifier: Decimal.new(0)
    }
    
    case Products.create_product_variant(variant_attrs) do
      {:ok, _variant} ->
        variants = Products.get_product_variants(socket.assigns.product.id)
        {:noreply, assign(socket, variants: variants) |> put_flash(:info, "Variant added successfully")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add variant")}
    end
  end

  def handle_event("delete_variant", %{"variant_id" => variant_id}, socket) do
    case Products.delete_product_variant(variant_id) do
      {:ok, _variant} ->
        variants = Products.get_product_variants(socket.assigns.product.id)
        {:noreply, assign(socket, variants: variants) |> put_flash(:info, "Variant deleted successfully")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete variant")}
    end
  end
end
```

## Environment Variables

Add to your `.env` file:
```bash
# Shippo Configuration
SHIPPO_API_KEY=your_shippo_api_key_here

# MessageBird Configuration
MESSAGEBIRD_API_KEY=your_messagebird_api_key_here
MESSAGEBIRD_ORIGINATOR=Shomp

# Beehiiv Configuration
BEEHIIV_API_KEY=your_beehiiv_api_key_here
```

## Routes

```elixir
# In router.ex
scope "/dashboard", ShompWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  # Product variants management
  live "/products/:product_id/variants", ProductLive.Variants, :index
  
  # Newsletter management
  live "/newsletter", NewsletterLive.Index, :index
end

scope "/", ShompWeb do
  pipe_through :browser
  
  # Newsletter signup
  post "/newsletter/subscribe", NewsletterController, :subscribe
end
```

## Implementation Priority

### Week 1: Core Integrations
1. **Shippo Integration**: Real shipping label generation
2. **MessageBird SMS**: Order notifications
3. **Basic Testing**: Test both integrations thoroughly

### Week 2: Beehiiv Integration
1. **Beehiiv API**: Newsletter signup forms
2. **Error Handling**: Robust error handling
3. **Testing**: Test newsletter functionality

### Week 3: Audience Management
1. **Database Schema**: Newsletter subscriptions
2. **Store Page Integration**: Newsletter signup components
3. **Analytics**: Basic audience metrics

### Week 4: Shopping Cart (Optional)
1. **Multi-Store Cart**: Unified cart system
2. **Checkout Integration**: Multi-store checkout
3. **Testing**: Cart functionality

### Week 5: Clothing Inventory
1. **Size Variants**: Product variants system
2. **Inventory Management**: Seller interface
3. **Size Selection**: Customer interface
4. **Testing**: Complete clothing workflow

## Testing Checklist

### Shippo Integration
- [ ] Create shipping label for physical order
- [ ] Calculate shipping rates during checkout
- [ ] Handle API errors gracefully
- [ ] Test with different carriers (USPS, FedEx, UPS)

### MessageBird SMS
- [ ] Send SMS to seller for new physical order
- [ ] Send SMS to buyer for order updates
- [ ] Handle SMS delivery failures
- [ ] Test with different phone number formats

### Beehiiv Integration
- [ ] Subscribe email to newsletter
- [ ] Handle subscription errors
- [ ] Test unsubscribe functionality
- [ ] Verify email delivery

### Audience Management
- [ ] Store page newsletter signup
- [ ] Email validation
- [ ] Subscription tracking
- [ ] Analytics display

### Shopping Cart
- [ ] Add products from different stores
- [ ] Update quantities
- [ ] Remove items
- [ ] Checkout process

### Clothing Inventory
- [ ] Add size variants to products
- [ ] Update inventory counts
- [ ] Size selection during purchase
- [ ] Low stock alerts

## Success Metrics

### Integration Reliability
- **Shippo**: >95% successful label generation
- **MessageBird**: >98% SMS delivery rate
- **Beehiiv**: >90% successful subscriptions

### User Experience
- **Cart Abandonment**: <30% for multi-store carts
- **Size Selection**: <5% errors in size selection
- **Newsletter Signup**: >10% conversion rate on store pages

### Platform Performance
- **API Response Times**: <2 seconds for all integrations
- **Error Rates**: <1% for all third-party integrations
- **Uptime**: >99.5% for all features

This MVP Core 19 provides a comprehensive roadmap for completing your initial release with all the remaining features you mentioned. The phased approach ensures manageable implementation while maintaining platform stability.
