defmodule ShompWeb.UniversalOrderLive.Show do
  use ShompWeb, :live_view

  alias Shomp.UniversalOrders
  alias Shomp.Stores

  import ShompWeb.OrderComponents

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def mount(%{"universal_order_id" => universal_order_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    IO.puts("=== MANAGE BUTTON CLICKED - COMPREHENSIVE DEBUG ===")
    IO.puts("Universal Order ID: #{universal_order_id}")
    IO.puts("User ID: #{user.id}")
    IO.puts("User Email: #{user.email}")

    # Get the order and verify the user owns a store that has products in this order
    case UniversalOrders.get_universal_order_by_id(universal_order_id) do
      nil ->
        IO.puts("❌ ORDER NOT FOUND!")
        {:ok,
         socket
         |> put_flash(:error, "Order not found")
         |> push_navigate(to: ~p"/dashboard/orders")}

      universal_order ->
        IO.puts("✅ ORDER FOUND!")
        IO.puts("Order ID: #{universal_order.id}")
        IO.puts("Order Status: #{universal_order.status}")
        IO.puts("Order Payment Status: #{universal_order.payment_status}")
        IO.puts("Order Total: #{universal_order.total_amount}")
        IO.puts("Order Store ID: #{universal_order.store_id}")
        IO.puts("Customer: #{universal_order.customer_name} (#{universal_order.customer_email})")

        # Preload the necessary associations first
        universal_order = universal_order
        |> Shomp.Repo.preload([:user])

        # Manually load order items since association is broken
        import Ecto.Query
        order_items = from(u in Shomp.UniversalOrders.UniversalOrderItem,
          where: u.universal_order_id == ^universal_order_id,
          preload: [:product]
        ) |> Shomp.Repo.all()

        # Manually set the order items
        universal_order = %{universal_order | universal_order_items: order_items}

        IO.puts("After manual load - universal_order_items count: #{length(universal_order.universal_order_items)}")

        # Check if user owns any store that has products in this order
        store_ids = universal_order.universal_order_items
        |> Enum.map(& &1.store_id)
        |> Enum.uniq()

        user_store_ids = Stores.list_stores_by_user(user.id)
        |> Enum.map(& &1.store_id)

        IO.puts("Order store IDs: #{inspect(store_ids)}")
        IO.puts("User store IDs: #{inspect(user_store_ids)}")
        IO.puts("Has access: #{Enum.any?(store_ids, fn store_id -> store_id in user_store_ids end)}")

        # Debug each order item
        Enum.with_index(universal_order.universal_order_items, fn item, index ->
          IO.puts("Item #{index + 1}:")
          IO.puts("  - Product ID: #{item.product_immutable_id}")
          IO.puts("  - Store ID: #{item.store_id}")
          IO.puts("  - Quantity: #{item.quantity}")
          IO.puts("  - Unit Price: #{item.unit_price}")
          IO.puts("  - Total Price: #{item.total_price}")
          IO.puts("  - Product Title: #{item.product.title}")
        end)

        if not Enum.any?(store_ids, fn store_id -> store_id in user_store_ids end) do
          IO.puts("❌ ACCESS DENIED - User doesn't own any stores with products in this order")
          {:ok,
           socket
           |> put_flash(:error, "You don't have access to this order")
           |> push_navigate(to: ~p"/dashboard/orders")}
        else
          IO.puts("✅ ACCESS GRANTED - User owns stores with products in this order")

          # Initialize forms
          status_form = to_form(%{"shipping_status" => universal_order.shipping_status || "ordered"}, as: :status)
          notes_form = to_form(%{"seller_notes" => universal_order.seller_notes || ""}, as: :notes)

          socket =
            socket
            |> assign(:universal_order, universal_order)
            |> assign(:status_form, status_form)
            |> assign(:notes_form, notes_form)
            |> assign(:show_tracking_input, universal_order.shipping_status in ["label_printed", "shipped"])
            |> assign(:page_title, "Order ##{universal_order.universal_order_id}")

          {:ok, socket}
        end
    end
  end

  @impl true
  def render(assigns) do
    IO.puts("=== RENDERING ORDER MANAGEMENT PAGE ===")
    IO.puts("Universal Order: #{assigns.universal_order.universal_order_id}")
    IO.puts("Order Items Count: #{length(assigns.universal_order.universal_order_items)}")
    IO.puts("Order Status: #{assigns.universal_order.shipping_status}")
    IO.puts("Order Total: #{assigns.universal_order.total_amount}")

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.header>
            Order #<%= String.slice(@universal_order.universal_order_id, 0, 8) %>
            <:subtitle>Manage this order</:subtitle>
            <:actions>
              <.link href={~p"/dashboard/orders"} class="btn btn-outline">
                ← Back to Orders
              </.link>
            </:actions>
          </.header>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Order Details -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Order Items -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Order Items</h2>
              </div>
              <div class="p-6">
                <div class="space-y-4">
                  <%= for order_item <- @universal_order.universal_order_items do %>
                    <div class="flex items-center justify-between py-3 px-4 bg-base-200 rounded-lg">
                      <div class="flex items-center space-x-4">
                        <div class="w-16 h-16 bg-base-300 rounded-lg flex items-center justify-center">
                          <%= if order_item.product.image_thumb do %>
                            <img src={order_item.product.image_thumb} alt={order_item.product.title} class="w-full h-full object-cover rounded-lg" />
                          <% else %>
                            <div class="text-base-content/40 text-xs">No Image</div>
                          <% end %>
                        </div>
                        <div>
                          <h3 class="font-medium text-base-content"><%= order_item.product.title %></h3>
                          <p class="text-sm text-base-content/60">Quantity: <%= order_item.quantity %></p>
                          <p class="text-sm text-base-content/60">Price: $<%= Decimal.to_string(order_item.unit_price, :normal) %></p>
                          <p class="text-sm text-base-content/60">Store ID: <%= order_item.store_id %></p>
                        </div>
                      </div>
                      <div class="text-right">
                        <p class="font-semibold text-base-content">$<%= Decimal.to_string(order_item.unit_price, :normal) %></p>
                        <p class="text-sm text-base-content/60">each</p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Order Management -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Order Management</h2>
              </div>
              <div class="p-6 space-y-6">
                <!-- Status Update -->
                <div>
                  <h3 class="text-md font-medium text-base-content mb-3">Update Order Status</h3>
                  <.form for={@status_form} phx-change="status_changed" phx-submit="update_status" class="space-y-4">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">Shipping Status</label>
                        <select name="shipping_status" class="select select-bordered w-full">
                          <option value="ordered" selected={@status_form.params["shipping_status"] == "ordered"}>Ordered</option>
                          <option value="processing" selected={@status_form.params["shipping_status"] == "processing"}>Processing</option>
                          <option value="label_printed" selected={@status_form.params["shipping_status"] == "label_printed"}>Label Printed</option>
                          <option value="shipped" selected={@status_form.params["shipping_status"] == "shipped"}>Shipped</option>
                          <option value="in_transit" selected={@status_form.params["shipping_status"] == "in_transit"}>In Transit</option>
                          <option value="delivered" selected={@status_form.params["shipping_status"] == "delivered"}>Delivered</option>
                          <option value="returned" selected={@status_form.params["shipping_status"] == "returned"}>Returned</option>
                        </select>
                      </div>

                      <%= if @show_tracking_input do %>
                        <div>
                          <label class="block text-sm font-medium text-base-content mb-2">Tracking Number</label>
                          <input
                            type="text"
                            name="tracking_number"
                            value={@universal_order.tracking_number || ""}
                            placeholder="Enter tracking number"
                            class="input input-bordered w-full"
                          />
                        </div>
                        <div>
                          <label class="block text-sm font-medium text-base-content mb-2">Carrier</label>
                          <input
                            type="text"
                            name="carrier"
                            value={@universal_order.carrier || ""}
                            placeholder="e.g., UPS, FedEx, USPS"
                            class="input input-bordered w-full"
                          />
                        </div>
                      <% end %>
                    </div>

                    <button type="submit" class="btn btn-primary">Update Status</button>
                  </.form>
                </div>

                <!-- Seller Notes -->
                <div>
                  <h3 class="text-md font-medium text-base-content mb-3">Seller Notes</h3>
                  <.form for={@notes_form} phx-submit="update_notes" class="space-y-4">
                    <div>
                      <textarea
                        name="seller_notes"
                        rows="3"
                        placeholder="Add internal notes about this order..."
                        class="textarea textarea-bordered w-full"
                      ><%= @notes_form.params["seller_notes"] || "" %></textarea>
                    </div>
                    <button type="submit" class="btn btn-outline">Save Notes</button>
                  </.form>
                </div>
              </div>
            </div>
          </div>

          <!-- Order Summary -->
          <div class="space-y-6">
            <!-- Order Info -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Order Information</h2>
              </div>
              <div class="p-6 space-y-4">
                <div class="flex justify-between">
                  <span class="text-base-content/70">Order ID</span>
                  <span class="font-mono text-sm"><%= @universal_order.universal_order_id %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Date</span>
                  <span><%= Calendar.strftime(@universal_order.inserted_at, "%b %d, %Y at %I:%M %p") %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Customer</span>
                  <span><%= @universal_order.customer_name %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Email</span>
                  <span class="text-sm"><%= @universal_order.customer_email %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Total Amount</span>
                  <span class="font-semibold">$<%= Decimal.to_string(@universal_order.total_amount, :normal) %></span>
                </div>
                <%= if Decimal.gt?(@universal_order.platform_fee_amount, Decimal.new("0")) do %>
                  <div class="flex justify-between">
                    <span class="text-base-content/70">Shomp Donation (5%)</span>
                    <span class="text-success">$<%= Decimal.to_string(@universal_order.platform_fee_amount, :normal) %></span>
                  </div>
                <% end %>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Status</span>
                  <.status_badge status={@universal_order.shipping_status} class="badge-sm" />
                </div>
                <%= if @universal_order.tracking_number do %>
                  <div class="flex justify-between">
                    <span class="text-base-content/70">Tracking</span>
                    <span class="font-mono text-sm"><%= @universal_order.tracking_number %></span>
                  </div>
                <% end %>
                <%= if @universal_order.carrier do %>
                  <div class="flex justify-between">
                    <span class="text-base-content/70">Carrier</span>
                    <span><%= @universal_order.carrier %></span>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Shipping Address -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Shipping Address</h2>
              </div>
              <div class="p-6">
                <div class="text-sm text-base-content/70">
                  <p><%= @universal_order.customer_name %></p>
                  <p><%= @universal_order.shipping_address_line1 %></p>
                  <%= if @universal_order.shipping_address_line2 && @universal_order.shipping_address_line2 != "" do %>
                    <p><%= @universal_order.shipping_address_line2 %></p>
                  <% end %>
                  <p><%= @universal_order.shipping_address_city %>, <%= @universal_order.shipping_address_state %> <%= @universal_order.shipping_address_postal_code %></p>
                  <p><%= @universal_order.shipping_address_country %></p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("status_changed", %{"shipping_status" => status}, socket) do
    IO.puts("=== STATUS CHANGED EVENT ===")
    IO.puts("New Status: #{status}")
    show_tracking = status in ["label_printed", "shipped"]
    IO.puts("Show Tracking Input: #{show_tracking}")
    status_form = to_form(%{"shipping_status" => status}, as: :status)

    {:noreply,
     socket
     |> assign(:show_tracking_input, show_tracking)
     |> assign(:status_form, status_form)}
  end

  @impl true
  def handle_event("update_status", %{"shipping_status" => status, "tracking_number" => tracking, "carrier" => carrier}, socket) do
    IO.puts("=== UPDATE STATUS EVENT ===")
    IO.puts("Status: #{status}")
    IO.puts("Tracking: #{tracking}")
    IO.puts("Carrier: #{carrier}")

    universal_order = socket.assigns.universal_order

    attrs = %{
      shipping_status: status,
      tracking_number: tracking,
      carrier: carrier
    }

    case UniversalOrders.update_universal_order(universal_order, attrs) do
      {:ok, updated_order} ->
        # Broadcast the update
        Phoenix.PubSub.broadcast(Shomp.PubSub, "universal_orders", %{
          event: "universal_order_updated",
          payload: updated_order
        })

        status_form = to_form(%{"shipping_status" => updated_order.shipping_status}, as: :status)

        {:noreply,
         socket
         |> put_flash(:info, "Order status updated successfully")
         |> assign(:universal_order, updated_order)
         |> assign(:status_form, status_form)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update order status")}
    end
  end

  @impl true
  def handle_event("update_notes", %{"seller_notes" => notes}, socket) do
    universal_order = socket.assigns.universal_order

    case UniversalOrders.update_universal_order(universal_order, %{seller_notes: notes}) do
      {:ok, updated_order} ->
        notes_form = to_form(%{"seller_notes" => updated_order.seller_notes || ""}, as: :notes)

        {:noreply,
         socket
         |> put_flash(:info, "Notes updated successfully")
         |> assign(:universal_order, updated_order)
         |> assign(:notes_form, notes_form)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update notes")}
    end
  end

  @impl true
  def handle_info(%{event: "universal_order_updated", payload: updated_order}, socket) do
    if updated_order.id == socket.assigns.universal_order.id do
      {:noreply, assign(socket, :universal_order, updated_order)}
    else
      {:noreply, socket}
    end
  end

  defp get_status_badge_class(status) do
    case status do
      "ordered" -> "badge badge-neutral"
      "processing" -> "badge badge-info"
      "label_printed" -> "badge badge-warning"
      "shipped" -> "badge badge-primary"
      "in_transit" -> "badge badge-primary"
      "delivered" -> "badge badge-success"
      "returned" -> "badge badge-error"
      _ -> "badge badge-neutral"
    end
  end
end
