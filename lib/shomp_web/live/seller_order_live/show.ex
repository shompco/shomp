defmodule ShompWeb.SellerOrderLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Orders
  alias Shomp.Stores

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.header>
            Order #<%= String.slice(@order.immutable_id, 0, 8) %>
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
                  <%= for item <- @order.order_items do %>
                    <div class="flex items-center space-x-4 p-4 bg-base-50 rounded-lg">
                      <%= if item.product.image_thumb do %>
                        <img src={item.product.image_thumb} alt={item.product.title} class="w-16 h-16 rounded object-cover" />
                      <% else %>
                        <div class="w-16 h-16 bg-base-200 rounded flex items-center justify-center">
                          <svg class="w-8 h-8 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                        </div>
                      <% end %>
                      <div class="flex-1">
                        <h3 class="font-medium text-base-content"><%= item.product.title %></h3>
                        <p class="text-sm text-base-content/60">Quantity: <%= item.quantity %></p>
                        <p class="text-sm text-base-content/60">Price: $<%= Decimal.to_string(item.price, :normal) %></p>
                      </div>
                      <div class="text-right">
                        <p class="font-semibold text-base-content">
                          $<%= Decimal.to_string(Decimal.mult(item.price, item.quantity), :normal) %>
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Order Total -->
                <div class="mt-6 pt-4 border-t border-base-300">
                  <div class="flex justify-between items-center text-lg font-semibold">
                    <span>Total</span>
                    <span>$<%= Decimal.to_string(@order.total_amount, :normal) %></span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Customer Information -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Customer Information</h2>
              </div>
              <div class="p-6">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="text-sm font-medium text-base-content/60">Name</label>
                    <p class="text-base-content"><%= @order.user.name || "Not provided" %></p>
                  </div>
                  <div>
                    <label class="text-sm font-medium text-base-content/60">Email</label>
                    <p class="text-base-content"><%= @order.user.email %></p>
                  </div>
                </div>
              </div>
            </div>

            <!-- Shipping Address -->
            <%= if @order.shipping_name do %>
              <div class="bg-base-100 border border-base-300 rounded-lg">
                <div class="px-6 py-4 border-b border-base-300">
                  <h2 class="text-lg font-semibold text-base-content">Shipping Address</h2>
                </div>
                <div class="p-6">
                  <div class="text-base-content">
                    <p><%= @order.shipping_name %></p>
                    <p><%= @order.shipping_address_line1 %></p>
                    <%= if @order.shipping_address_line2 do %>
                      <p><%= @order.shipping_address_line2 %></p>
                    <% end %>
                    <p><%= @order.shipping_city %>, <%= @order.shipping_state %> <%= @order.shipping_postal_code %></p>
                    <p><%= @order.shipping_country %></p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Order Management -->
          <div class="space-y-6">
            <!-- Order Status -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Order Status</h2>
              </div>
              <div class="p-6">
                <div class="space-y-4">
                  <!-- Current Status -->
                  <div>
                    <label class="text-sm font-medium text-base-content/60">Current Status</label>
                    <div class="mt-1">
                      <span class="badge badge-lg badge-primary">
                        <%= String.capitalize(@order.shipping_status) %>
                      </span>
                    </div>
                  </div>

                  <!-- Status Update Form -->
                  <.form for={@status_form} phx-submit="update_status" class="space-y-4">
                    <div>
                      <label class="block text-sm font-medium text-base-content mb-2">
                        Update Status
                      </label>
                      <select
                        name="shipping_status"
                        class="select select-bordered w-full"
                        phx-change="status_changed"
                      >
                        <option value="ordered" selected={@order.shipping_status == "ordered"}>Ordered</option>
                        <option value="label_printed" selected={@order.shipping_status == "label_printed"}>Label Printed</option>
                        <option value="shipped" selected={@order.shipping_status == "shipped"}>Shipped</option>
                        <option value="delivered" selected={@order.shipping_status == "delivered"}>Delivered</option>
                      </select>
                    </div>

                    <!-- Tracking Number Input -->
                    <%= if @show_tracking_input do %>
                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          Tracking Number
                        </label>
                        <input
                          type="text"
                          name="tracking_number"
                          value={@order.tracking_number || ""}
                          placeholder="Enter tracking number"
                          class="input input-bordered w-full"
                        />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          Carrier
                        </label>
                        <select name="carrier" class="select select-bordered w-full">
                          <option value="USPS" selected={@order.carrier == "USPS"}>USPS</option>
                          <option value="FedEx" selected={@order.carrier == "FedEx"}>FedEx</option>
                          <option value="UPS" selected={@order.carrier == "UPS"}>UPS</option>
                          <option value="DHL" selected={@order.carrier == "DHL"}>DHL</option>
                          <option value="Other" selected={@order.carrier == "Other"}>Other</option>
                        </select>
                      </div>
                    <% end %>

                    <button type="submit" class="btn btn-primary w-full">
                      Update Status
                    </button>
                  </.form>
                </div>
              </div>
            </div>

            <!-- Order Information -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Order Information</h2>
              </div>
              <div class="p-6">
                <div class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <span class="text-base-content/60">Order Date</span>
                    <span class="text-base-content"><%= Calendar.strftime(@order.inserted_at, "%b %d, %Y") %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-base-content/60">Order Time</span>
                    <span class="text-base-content"><%= Calendar.strftime(@order.inserted_at, "%I:%M %p") %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-base-content/60">Payment Status</span>
                    <span class="badge badge-sm badge-success"><%= String.capitalize(@order.payment_status) %></span>
                  </div>
                  <%= if @order.tracking_number do %>
                    <div class="flex justify-between">
                      <span class="text-base-content/60">Tracking</span>
                      <span class="text-base-content font-mono text-xs"><%= @order.tracking_number %></span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Notes -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Notes</h2>
              </div>
              <div class="p-6">
                <.form for={@notes_form} phx-submit="update_notes" class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      Seller Notes (Internal)
                    </label>
                    <textarea
                      name="seller_notes"
                      rows="3"
                      placeholder="Add internal notes about this order..."
                      class="textarea textarea-bordered w-full"
                    ><%= @order.seller_notes || "" %></textarea>
                  </div>
                  <button type="submit" class="btn btn-outline w-full">
                    Save Notes
                  </button>
                </.form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => order_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get the order and verify the user owns a store that has products in this order
    order = Orders.get_order!(order_id)

    # Check if user owns any store that has products in this order
    store_ids = order.order_items
    |> Enum.map(& &1.product.store_id)
    |> Enum.uniq()

    user_store_ids = Stores.list_stores_by_user(user.id)
    |> Enum.map(& &1.store_id)

    if not Enum.any?(store_ids, fn store_id -> store_id in user_store_ids end) do
      raise Phoenix.Router.NoRouteError, "Not found"
    end

    # Initialize forms
    status_form = to_form(%{"shipping_status" => order.shipping_status}, as: :status)
    notes_form = to_form(%{"seller_notes" => order.seller_notes || ""}, as: :notes)

    socket =
      socket
      |> assign(:order, order)
      |> assign(:status_form, status_form)
      |> assign(:notes_form, notes_form)
      |> assign(:show_tracking_input, order.shipping_status in ["label_printed", "shipped"])
      |> assign(:page_title, "Order ##{String.slice(order.immutable_id, 0, 8)}")

    {:ok, socket}
  end

  @impl true
  def handle_event("status_changed", %{"shipping_status" => status}, socket) do
    show_tracking = status in ["label_printed", "shipped"]

    {:noreply, assign(socket, :show_tracking_input, show_tracking)}
  end

  @impl true
  def handle_event("update_status", %{"shipping_status" => status, "tracking_number" => tracking, "carrier" => carrier}, socket) do
    order = socket.assigns.order

    attrs = %{
      shipping_status: status,
      tracking_number: tracking,
      carrier: carrier
    }

    # Add shipped_at timestamp when status changes to shipped
    attrs = if status == "shipped" and order.shipping_status != "shipped" do
      Map.put(attrs, :shipped_at, DateTime.utc_now())
    else
      attrs
    end

    # Add delivered_at timestamp when status changes to delivered
    attrs = if status == "delivered" and order.shipping_status != "delivered" do
      Map.put(attrs, :delivered_at, DateTime.utc_now())
    else
      attrs
    end

    case Orders.update_order_comprehensive(order, attrs) do
      {:ok, updated_order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order status updated successfully")
         |> assign(:order, updated_order)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update order status")}
    end
  end

  @impl true
  def handle_event("update_notes", %{"seller_notes" => notes}, socket) do
    order = socket.assigns.order

    case Orders.update_order_comprehensive(order, %{seller_notes: notes}) do
      {:ok, updated_order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Notes updated successfully")
         |> assign(:order, updated_order)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update notes")}
    end
  end

  @impl true
  def handle_info(%{event: "order_updated", payload: updated_order}, socket) do
    if updated_order.id == socket.assigns.order.id do
      {:noreply, assign(socket, :order, updated_order)}
    else
      {:noreply, socket}
    end
  end
end
