# MVP Core 7: Split Payments and Refund Tracking

## Overview
Enhanced database schema and admin interface for tracking universal orders, payment splits, and refunds with complete financial audit trails.

## 1. Database Schema with Immutable IDs

### A. Universal Orders Table
```elixir
# Migration: create_universal_orders
defmodule Shomp.Repo.Migrations.CreateUniversalOrders do
  use Ecto.Migration

  def change do
    create table(:universal_orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :universal_order_id, :string, null: false  # e.g., "UO_20240115_ABC123"
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :stripe_payment_intent_id, :string, null: false
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :status, :string, default: "pending", null: false
      add :payment_status, :string, default: "pending", null: false
      add :billing_address_id, references(:addresses, on_delete: :nilify_all)
      add :shipping_address_id, references(:addresses, on_delete: :nilify_all)
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:universal_orders, [:universal_order_id])
    create unique_index(:universal_orders, [:stripe_payment_intent_id])
    create index(:universal_orders, [:user_id])
    create index(:universal_orders, [:status])
  end
end
```

### B. Payment Splits Table
```elixir
# Migration: create_payment_splits
defmodule Shomp.Repo.Migrations.CreatePaymentSplits do
  use Ecto.Migration

  def change do
    create table(:payment_splits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :payment_split_id, :string, null: false  # e.g., "PS_20240115_ABC123"
      add :universal_order_id, :string, null: false
      add :stripe_payment_intent_id, :string, null: false
      add :store_id, :string, null: false
      add :stripe_account_id, :string, null: false
      add :store_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :stripe_transfer_id, :string
      add :transfer_status, :string, default: "pending"
      add :refunded_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :refund_status, :string, default: "none"
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:payment_splits, [:payment_split_id])
    create index(:payment_splits, [:universal_order_id])
    create index(:payment_splits, [:store_id])
    create index(:payment_splits, [:stripe_account_id])
  end
end
```

### C. Enhanced Refunds Table with Store Attribution
```elixir
# Migration: create_refunds
defmodule Shomp.Repo.Migrations.CreateRefunds do
  use Ecto.Migration

  def change do
    create table(:refunds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :refund_id, :string, null: false  # e.g., "RF_20240115_ABC123"
      add :universal_order_id, :string, null: false
      add :payment_split_id, :string, null: false
      add :store_id, :string, null: false  # Store being debited
      add :stripe_refund_id, :string, null: false
      add :refund_amount, :decimal, precision: 10, scale: 2, null: false
      add :refund_reason, :string, null: false
      add :refund_type, :string, null: false  # full, partial, item_specific
      add :status, :string, default: "pending", null: false
      add :processed_at, :utc_datetime
      add :stripe_charge_id, :string
      add :admin_notes, :text
      add :processed_by_user_id, references(:users, on_delete: :nilify_all)
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:refunds, [:refund_id])
    create unique_index(:refunds, [:stripe_refund_id])
    create index(:refunds, [:universal_order_id])
    create index(:refunds, [:payment_split_id])
    create index(:refunds, [:store_id])
    create index(:refunds, [:status])
  end
end
```

### D. Universal Order Items
```elixir
# Migration: create_universal_order_items
defmodule Shomp.Repo.Migrations.CreateUniversalOrderItems do
  use Ecto.Migration

  def change do
    create table(:universal_order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_item_id, :string, null: false  # e.g., "OI_20240115_ABC123"
      add :universal_order_id, :string, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :store_id, :string, null: false
      add :quantity, :integer, default: 1, null: false
      add :unit_price, :decimal, precision: 10, scale: 2, null: false
      add :total_price, :decimal, precision: 10, scale: 2, null: false
      add :store_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee_amount, :decimal, precision: 10, scale: 2, default: Decimal.new(0)
      add :payment_split_id, :string
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:universal_order_items, [:order_item_id])
    create index(:universal_order_items, [:universal_order_id])
    create index(:universal_order_items, [:product_id])
    create index(:universal_order_items, [:store_id])
  end
end
```

## 2. Context Modules

### A. Universal Orders Context
```elixir
# lib/shomp/universal_orders.ex
defmodule Shomp.UniversalOrders do
  @moduledoc """
  The UniversalOrders context for managing multi-store orders.
  """

  alias Shomp.Repo
  alias Shomp.UniversalOrders.UniversalOrder

  def create_universal_order(attrs \\ %{}) do
    %UniversalOrder{}
    |> UniversalOrder.changeset(attrs)
    |> Repo.insert()
  end

  def get_universal_order_by_id(universal_order_id) do
    Repo.get_by(UniversalOrder, universal_order_id: universal_order_id)
    |> Repo.preload([:universal_order_items, :payment_splits, :refunds])
  end

  def list_universal_orders(filters \\ %{}) do
    UniversalOrder
    |> apply_filters(filters)
    |> Repo.all()
    |> Repo.preload([:universal_order_items, :payment_splits])
  end

  defp apply_filters(query, %{status: status}), do: where(query, [u], u.status == ^status)
  defp apply_filters(query, %{user_id: user_id}), do: where(query, [u], u.user_id == ^user_id)
  defp apply_filters(query, %{date_from: date}), do: where(query, [u], u.inserted_at >= ^date)
  defp apply_filters(query, %{date_to: date}), do: where(query, [u], u.inserted_at <= ^date)
  defp apply_filters(query, _), do: query
end
```

### B. Payment Splits Context
```elixir
# lib/shomp/payment_splits.ex
defmodule Shomp.PaymentSplits do
  @moduledoc """
  The PaymentSplits context for managing payment distributions.
  """

  alias Shomp.Repo
  alias Shomp.PaymentSplits.PaymentSplit

  def create_payment_split(attrs \\ %{}) do
    %PaymentSplit{}
    |> PaymentSplit.changeset(attrs)
    |> Repo.insert()
  end

  def get_splits_by_universal_order(universal_order_id) do
    PaymentSplit
    |> where([p], p.universal_order_id == ^universal_order_id)
    |> Repo.all()
  end

  def update_split_refund_amount(split_id, refund_amount) do
    split = Repo.get_by(PaymentSplit, payment_split_id: split_id)
    
    new_refunded = Decimal.add(split.refunded_amount, refund_amount)
    refund_status = if Decimal.equal?(new_refunded, split.total_amount), do: "full", else: "partial"
    
    split
    |> PaymentSplit.refund_changeset(%{
      refunded_amount: new_refunded,
      refund_status: refund_status
    })
    |> Repo.update()
  end
end
```

### C. Refunds Context
```elixir
# lib/shomp/refunds.ex
defmodule Shomp.Refunds do
  @moduledoc """
  The Refunds context for managing refunds with store attribution.
  """

  alias Shomp.Repo
  alias Shomp.Refunds.Refund

  def create_refund(attrs \\ %{}) do
    %Refund{}
    |> Refund.changeset(attrs)
    |> Repo.insert()
  end

  def get_refunds_by_universal_order(universal_order_id) do
    Refund
    |> where([r], r.universal_order_id == ^universal_order_id)
    |> Repo.all()
  end

  def get_refunds_by_store(store_id) do
    Refund
    |> where([r], r.store_id == ^store_id)
    |> Repo.all()
  end

  def process_refund(refund_id, admin_user_id) do
    refund = Repo.get_by(Refund, refund_id: refund_id)
    
    # Update payment split refund amounts
    Shomp.PaymentSplits.update_split_refund_amount(refund.payment_split_id, refund.refund_amount)
    
    # Update refund status
    refund
    |> Refund.process_changeset(%{
      status: "succeeded",
      processed_at: DateTime.utc_now(),
      processed_by_user_id: admin_user_id
    })
    |> Repo.update()
  end
end
```

## 3. Admin Interface

### A. Universal Order Dashboard
```elixir
# lib/shomp_web/live/admin_live/universal_orders.ex
defmodule ShompWeb.AdminLive.UniversalOrders do
  use ShompWeb, :live_view

  alias Shomp.UniversalOrders
  alias Shomp.PaymentSplits
  alias Shomp.Refunds

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(_params, _session, socket) do
    orders = UniversalOrders.list_universal_orders()
    
    socket = 
      socket
      |> assign(:orders, orders)
      |> assign(:page_title, "Universal Orders")

    {:ok, socket}
  end

  def handle_event("view_order", %{"universal_order_id" => order_id}, socket) do
    order = UniversalOrders.get_universal_order_by_id(order_id)
    splits = PaymentSplits.get_splits_by_universal_order(order_id)
    refunds = Refunds.get_refunds_by_universal_order(order_id)
    
    {:noreply,
     socket
     |> assign(:selected_order, order)
     |> assign(:payment_splits, splits)
     |> assign(:refunds, refunds)
     |> push_patch(to: ~p"/admin/universal-orders/#{order_id}")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Universal Orders</h1>
          <p class="mt-2 text-gray-600">Track multi-store orders and payment splits</p>
        </div>

        <!-- Orders Table -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Order ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Customer</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Platform Fee</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for order <- @orders do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= order.universal_order_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    User #<%= order.user_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= order.total_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= order.platform_fee_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                      <%= order.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= Calendar.strftime(order.inserted_at, "%Y-%m-%d %H:%M") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button
                      phx-click="view_order"
                      phx-value-universal_order_id={order.universal_order_id}
                      class="text-indigo-600 hover:text-indigo-900"
                    >
                      View Details
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
```

### B. Payment Split Viewer
```elixir
# lib/shomp_web/live/admin_live/payment_splits.ex
defmodule ShompWeb.AdminLive.PaymentSplits do
  use ShompWeb, :live_view

  alias Shomp.PaymentSplits
  alias Shomp.Stores

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(%{"universal_order_id" => order_id}, _session, socket) do
    splits = PaymentSplits.get_splits_by_universal_order(order_id)
    splits_with_stores = Enum.map(splits, fn split ->
      store = Stores.get_store_by_store_id(split.store_id)
      Map.put(split, :store, store)
    end)
    
    socket = 
      socket
      |> assign(:splits, splits_with_stores)
      |> assign(:universal_order_id, order_id)
      |> assign(:page_title, "Payment Splits - #{order_id}")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Payment Splits</h1>
          <p class="mt-2 text-gray-600">Order: <%= @universal_order_id %></p>
        </div>

        <!-- Splits Table -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Split ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Store</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Store Amount</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Platform Fee</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Refunded</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for split <- @splits do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= split.payment_split_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= split.store.name %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.store_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.platform_fee_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.total_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= split.refunded_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">
                      <%= split.transfer_status %>
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
```

### C. Refund Management Interface
```elixir
# lib/shomp_web/live/admin_live/refunds.ex
defmodule ShompWeb.AdminLive.Refunds do
  use ShompWeb, :live_view

  alias Shomp.Refunds
  alias Shomp.Stores

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(_params, _session, socket) do
    refunds = Refunds.list_all_refunds()
    refunds_with_stores = Enum.map(refunds, fn refund ->
      store = Stores.get_store_by_store_id(refund.store_id)
      Map.put(refund, :store, store)
    end)
    
    socket = 
      socket
      |> assign(:refunds, refunds_with_stores)
      |> assign(:page_title, "Refund Management")

    {:ok, socket}
  end

  def handle_event("process_refund", %{"refund_id" => refund_id}, socket) do
    admin_user_id = socket.assigns.current_scope.user.id
    
    case Refunds.process_refund(refund_id, admin_user_id) do
      {:ok, _refund} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Refund processed successfully")
         |> assign(:refunds, Refunds.list_all_refunds())}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to process refund")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Refund Management</h1>
          <p class="mt-2 text-gray-600">Track and process refunds with store attribution</p>
        </div>

        <!-- Refunds Table -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Refund ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Order ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Store (Debited)</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Amount</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reason</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for refund <- @refunds do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= refund.refund_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= refund.universal_order_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= refund.store.name %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= refund.refund_amount %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= refund.refund_reason %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800">
                      <%= refund.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <%= if refund.status == "pending" do %>
                      <button
                        phx-click="process_refund"
                        phx-value-refund_id={refund.refund_id}
                        class="text-green-600 hover:text-green-900"
                      >
                        Process
                      </button>
                    <% else %>
                      <span class="text-gray-400">Processed</span>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
```

## 4. Routes
```elixir
# lib/shomp_web/router.ex
scope "/admin", ShompWeb do
  live "/universal-orders", AdminLive.UniversalOrders, :index
  live "/universal-orders/:id", AdminLive.UniversalOrders, :show
  live "/payment-splits/:universal_order_id", AdminLive.PaymentSplits, :show
  live "/refunds", AdminLive.Refunds, :index
end
```

## 5. Key Features

### A. Immutable ID Generation
```elixir
defp generate_universal_order_id do
  date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
  random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false)
  "UO_#{date}_#{random}"
end

defp generate_payment_split_id do
  date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
  random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false)
  "PS_#{date}_#{random}"
end

defp generate_refund_id do
  date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
  random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false)
  "RF_#{date}_#{random}"
end
```

### B. Store Attribution in Refunds
- Every refund tracks which store is being debited
- Clear audit trail of refund impact per store
- Support for partial refunds per store
- Platform fee refund calculations

### C. Admin Interface Benefits
- View orders by universal ID
- See complete payment split breakdown
- Track refunds with store attribution
- Process refunds with proper store debiting
- Financial reporting and audit trails

This system provides complete financial transparency and control over multi-store orders, payment splits, and refunds while using immutable IDs throughout.
