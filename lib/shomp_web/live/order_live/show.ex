defmodule ShompWeb.OrderLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Orders

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.header>
            Order #<%= String.slice(@order.immutable_id, 0, 8) %>
            <:subtitle>Order details and tracking information</:subtitle>
            <:actions>
              <.link href={~p"/orders"} class="btn btn-outline">
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
                        <%= if item.product.type == "digital" do %>
                          <p class="text-xs text-primary">Digital Product</p>
                        <% end %>
                      </div>
                      <div class="text-right">
                        <p class="font-semibold text-base-content">
                          $<%= Decimal.to_string(Decimal.mult(item.price, item.quantity), :normal) %>
                        </p>
                        <%= if item.product.type == "digital" do %>
                          <.link
                            href={~p"/downloads/#{@order.immutable_id}"}
                            class="btn btn-xs btn-primary mt-2"
                          >
                            Download
                          </.link>
                        <% end %>
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

            <!-- Tracking Information -->
            <%= if @order.tracking_number do %>
              <div class="bg-base-100 border border-base-300 rounded-lg">
                <div class="px-6 py-4 border-b border-base-300">
                  <h2 class="text-lg font-semibold text-base-content">Tracking Information</h2>
                </div>
                <div class="p-6">
                  <div class="space-y-4">
                    <div class="flex items-center justify-between">
                      <div>
                        <p class="text-sm text-base-content/60">Tracking Number</p>
                        <p class="font-mono text-base-content"><%= @order.tracking_number %></p>
                      </div>
                      <%= if @order.carrier do %>
                        <div class="text-right">
                          <p class="text-sm text-base-content/60">Carrier</p>
                          <p class="text-base-content"><%= @order.carrier %></p>
                        </div>
                      <% end %>
                    </div>

                    <!-- Tracking Links -->
                    <div class="flex flex-wrap gap-2">
                      <%= if @order.carrier == "USPS" do %>
                        <.link
                          href={"https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=#{@order.tracking_number}"}
                          target="_blank"
                          class="btn btn-sm btn-outline"
                        >
                          Track on USPS
                        </.link>
                      <% end %>
                      <%= if @order.carrier == "FedEx" do %>
                        <.link
                          href={"https://www.fedex.com/fedextrack/?trknbr=#{@order.tracking_number}"}
                          target="_blank"
                          class="btn btn-sm btn-outline"
                        >
                          Track on FedEx
                        </.link>
                      <% end %>
                      <%= if @order.carrier == "UPS" do %>
                        <.link
                          href={"https://www.ups.com/track?track=yes&trackNums=#{@order.tracking_number}"}
                          target="_blank"
                          class="btn btn-sm btn-outline"
                        >
                          Track on UPS
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Order Information -->
          <div class="space-y-6">
            <!-- Order Status -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Order Status</h2>
              </div>
              <div class="p-6">
                <div class="space-y-4">
                  <!-- Status Progress -->
                  <div class="space-y-3">
                    <div class="flex items-center space-x-3">
                      <div class={"w-3 h-3 rounded-full #{if @order.shipping_status in ["ordered", "label_printed", "shipped", "delivered"], do: "bg-primary", else: "bg-base-300"}"}></div>
                      <span class="text-sm text-base-content">Order Placed</span>
                    </div>
                    <div class="flex items-center space-x-3">
                      <div class={"w-3 h-3 rounded-full #{if @order.shipping_status in ["label_printed", "shipped", "delivered"], do: "bg-primary", else: "bg-base-300"}"}></div>
                      <span class="text-sm text-base-content">Label Printed</span>
                    </div>
                    <div class="flex items-center space-x-3">
                      <div class={"w-3 h-3 rounded-full #{if @order.shipping_status in ["shipped", "delivered"], do: "bg-primary", else: "bg-base-300"}"}></div>
                      <span class="text-sm text-base-content">Shipped</span>
                    </div>
                    <div class="flex items-center space-x-3">
                      <div class={"w-3 h-3 rounded-full #{if @order.shipping_status == "delivered", do: "bg-primary", else: "bg-base-300"}"}></div>
                      <span class="text-sm text-base-content">Delivered</span>
                    </div>
                  </div>

                  <!-- Current Status -->
                  <div class="pt-4 border-t border-base-300">
                    <div class="text-center">
                      <span class="badge badge-lg badge-primary">
                        <%= String.capitalize(@order.shipping_status) %>
                      </span>
                    </div>
                  </div>
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
                  <%= if @order.shipped_at do %>
                    <div class="flex justify-between">
                      <span class="text-base-content/60">Shipped Date</span>
                      <span class="text-base-content"><%= Calendar.strftime(@order.shipped_at, "%b %d, %Y") %></span>
                    </div>
                  <% end %>
                  <%= if @order.delivered_at do %>
                    <div class="flex justify-between">
                      <span class="text-base-content/60">Delivered Date</span>
                      <span class="text-base-content"><%= Calendar.strftime(@order.delivered_at, "%b %d, %Y") %></span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Support -->
            <div class="bg-base-100 border border-base-300 rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-semibold text-base-content">Need Help?</h2>
              </div>
              <div class="p-6">
                <p class="text-sm text-base-content/60 mb-4">
                  Having issues with your order? We're here to help.
                </p>
                <div class="space-y-2">
                  <.link href={~p"/support"} class="btn btn-outline w-full">
                    Contact Support
                  </.link>
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
  def mount(%{"id" => order_immutable_id}, _session, socket) do
    user = socket.assigns.current_scope.user
    order = Orders.get_order_by_immutable_id!(order_immutable_id)

    # Verify the order belongs to the current user
    if order.user_id != user.id do
      raise Phoenix.Router.NoRouteError, "Not found"
    end

    socket =
      socket
      |> assign(:order, order)
      |> assign(:page_title, "Order ##{String.slice(order.immutable_id, 0, 8)}")

    {:ok, socket}
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
