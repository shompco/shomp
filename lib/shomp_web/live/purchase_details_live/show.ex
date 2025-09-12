defmodule ShompWeb.PurchaseDetailsLive.Show do
  use ShompWeb, :live_view

  alias Shomp.UniversalOrders
  import ShompWeb.OrderComponents

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def mount(%{"universal_order_id" => universal_order_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get the order and verify the user owns this purchase
    case UniversalOrders.get_universal_order_by_id(universal_order_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Purchase not found")
         |> push_navigate(to: ~p"/dashboard/purchases")}

      universal_order ->
        # Verify this user made this purchase
        if universal_order.user_id != user.id do
          {:ok,
           socket
           |> put_flash(:error, "You don't have access to this purchase")
           |> push_navigate(to: ~p"/dashboard/purchases")}
        else
          # Preload the necessary associations
          universal_order = universal_order
          |> Shomp.Repo.preload([:user])

          # Manually load order items with proper product preloading
          import Ecto.Query
          order_items = from(u in Shomp.UniversalOrders.UniversalOrderItem,
            where: u.universal_order_id == ^universal_order_id,
            preload: [:product]
          ) |> Shomp.Repo.all()

          # Debug: Check product data
          IO.puts("=== PURCHASE DETAILS DEBUG ===")
          IO.puts("Order items count: #{length(order_items)}")
          for {item, index} <- Enum.with_index(order_items) do
            IO.puts("Item #{index + 1}:")
            IO.puts("  Product loaded: #{item.product != nil}")
            if item.product do
              IO.puts("  Product title: #{item.product.title}")
              IO.puts("  Product image_thumb: #{inspect(item.product.image_thumb)}")
              IO.puts("  Product image_original: #{inspect(item.product.image_original)}")
            end
          end

          # Manually set the order items
          universal_order = %{universal_order | universal_order_items: order_items}

          # Subscribe to universal order updates
          Phoenix.PubSub.subscribe(Shomp.PubSub, "universal_orders")

          socket =
            socket
            |> assign(:universal_order, universal_order)
            |> assign(:page_title, "Purchase ##{universal_order.universal_order_id}")

          {:ok, socket}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.header>
            Purchase #<%= @universal_order.universal_order_id %>
            <:subtitle>Your purchase details</:subtitle>
            <:actions>
              <.link href={~p"/dashboard/purchases"} class="btn btn-outline">
                ← Back to Purchases
              </.link>
            </:actions>
          </.header>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Purchase Details -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Order Items -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Purchase Items</h2>
              </div>
              <div class="p-6">
                <div class="space-y-4">
                  <%= for order_item <- @universal_order.universal_order_items do %>
                    <div class="flex items-center justify-between py-3 px-4 bg-base-200 rounded-lg">
                      <div class="flex items-center space-x-4">
                        <div class="w-16 h-16 bg-base-300 rounded-lg flex items-center justify-center">
                          <%= cond do %>
                            <% order_item.product.image_thumb && order_item.product.image_thumb != "" -> %>
                              <img src={order_item.product.image_thumb} alt={order_item.product.title} class="w-full h-full object-cover rounded-lg" />
                            <% order_item.product.image_medium && order_item.product.image_medium != "" -> %>
                              <img src={order_item.product.image_medium} alt={order_item.product.title} class="w-full h-full object-cover rounded-lg" />
                            <% order_item.product.image_original && order_item.product.image_original != "" -> %>
                              <img src={order_item.product.image_original} alt={order_item.product.title} class="w-full h-full object-cover rounded-lg" />
                            <% true -> %>
                              <div class="text-base-content/40 text-xs">No Image</div>
                          <% end %>
                        </div>
                        <div>
                          <h3 class="font-medium text-base-content"><%= order_item.product.title %></h3>
                          <p class="text-sm text-base-content/60">Quantity: <%= order_item.quantity %></p>
                          <p class="text-sm text-base-content/60">Price: $<%= Decimal.to_string(order_item.unit_price, :normal) %></p>
                        </div>
                      </div>
                      <div class="text-right">
                        <p class="font-semibold text-base-content">$<%= Decimal.to_string(order_item.total_price, :normal) %></p>
                        <p class="text-sm text-base-content/60">total</p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <!-- Purchase Summary -->
          <div class="space-y-6">
            <!-- Purchase Info -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Purchase Information</h2>
              </div>
              <div class="p-6 space-y-4">
                <div class="flex justify-between">
                  <span class="text-base-content/70">Purchase ID</span>
                  <span class="font-mono text-sm"><%= @universal_order.universal_order_id %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Date</span>
                  <span><%= Calendar.strftime(@universal_order.inserted_at, "%b %d, %Y at %I:%M %p") %></span>
                </div>
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

            <!-- Order Summary -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Order Summary</h2>
              </div>
              <div class="p-6 space-y-3">
                <div class="flex justify-between">
                  <span class="text-base-content/70">Subtotal</span>
                  <span>$<%= Decimal.to_string(Decimal.sub(@universal_order.total_amount, @universal_order.platform_fee_amount), :normal) %></span>
                </div>
                <%= if Decimal.gt?(@universal_order.platform_fee_amount, Decimal.new("0")) do %>
                  <div class="flex justify-between">
                    <span class="text-base-content/70">Shomp Donation (5%) - Thank you!</span>
                    <span class="text-success">$<%= Decimal.to_string(@universal_order.platform_fee_amount, :normal) %></span>
                  </div>
                <% end %>
                <div class="border-t border-base-300 pt-3">
                  <div class="flex justify-between text-lg font-semibold">
                    <span>Total</span>
                    <span>$<%= Decimal.to_string(@universal_order.total_amount, :normal) %></span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Shipping Address -->
            <%= if @universal_order.shipping_address_line1 do %>
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
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info(%{event: "universal_order_updated", payload: updated_order}, socket) do
    current_order = socket.assigns.universal_order

    # Only update if this is the same order we're viewing
    if updated_order.id == current_order.id do
      IO.puts("=== PURCHASE DETAILS: Received order update via PubSub ===")
      IO.puts("Order ID: #{updated_order.universal_order_id}")
      IO.puts("New shipping status: #{updated_order.shipping_status}")
      IO.puts("Tracking number: #{updated_order.tracking_number}")
      IO.puts("Carrier: #{updated_order.carrier}")

      # Preserve the order items from the current order since the updated order may not have them preloaded
      updated_order_with_items = %{updated_order | universal_order_items: current_order.universal_order_items}

      {:noreply, assign(socket, :universal_order, updated_order_with_items)}
    else
      # Not our order, ignore
      {:noreply, socket}
    end
  end

  # Catch-all for other PubSub messages
  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
