defmodule ShompWeb.OrderLive.Index do
  use ShompWeb, :live_view

  alias Shomp.Orders

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl">
        <div class="mb-8">
          <.header>
            Order History
            <:subtitle>View all your past orders</:subtitle>
          </.header>
        </div>

        <%= if Enum.empty?(@orders) do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-base-content">No orders yet</h3>
            <p class="mt-1 text-sm text-base-content/60">Your orders will appear here once you make a purchase.</p>
            <div class="mt-6">
              <.link href={~p"/"} class="btn btn-primary">
                Browse Products
              </.link>
            </div>
          </div>
        <% else %>
          <div class="space-y-6">
            <%= for order <- @orders do %>
              <div class="bg-base-100 border border-base-300 rounded-lg">
                <div class="px-6 py-4 border-b border-base-300">
                  <div class="flex items-center justify-between">
                    <div>
                      <h2 class="text-lg font-semibold text-base-content">
                        Order #<%= String.slice(order.immutable_id, 0, 8) %>
                      </h2>
                      <p class="text-sm text-base-content/60">
                        Placed on <%= Calendar.strftime(order.inserted_at, "%B %d, %Y at %I:%M %p") %>
                      </p>
                    </div>
                    <div class="text-right">
                      <div class="flex items-center space-x-2">
                        <span class="badge badge-outline">
                          <%= String.capitalize(order.shipping_status) %>
                        </span>
                    <span class="text-lg font-semibold text-base-content">
                      $<%= Decimal.to_string(order.total_amount, :normal) %>
                    </span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="p-6">
                  <!-- Order Items -->
                  <div class="space-y-4 mb-6">
                    <%= for item <- order.order_items do %>
                      <div class="flex items-center space-x-4">
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

                  <!-- Order Status & Tracking -->
                  <div class="flex items-center justify-between pt-4 border-t border-base-300">
                    <div class="flex items-center space-x-4">
                      <!-- Status Badge -->
                      <div class="flex items-center space-x-2">
                        <span class="text-sm text-base-content/60">Status:</span>
                        <span class="badge badge-primary">
                          <%= String.capitalize(order.shipping_status) %>
                        </span>
                      </div>

                      <!-- Tracking Info -->
                      <%= if order.tracking_number do %>
                        <div class="flex items-center space-x-2">
                          <span class="text-sm text-base-content/60">Tracking:</span>
                          <span class="font-mono text-sm text-base-content"><%= order.tracking_number %></span>
                          <%= if order.carrier do %>
                            <span class="text-xs text-base-content/60">(<%= order.carrier %>)</span>
                          <% end %>
                        </div>
                      <% end %>
                    </div>

                    <!-- Action Buttons -->
                    <div class="flex items-center space-x-2">
                      <.link
                        href={~p"/orders/#{order.id}"}
                        class="btn btn-sm btn-outline"
                      >
                        View Details
                      </.link>

                      <!-- Download button for digital products -->
                      <%= if order.order_items |> Enum.any?(fn item -> item.product.type == "digital" end) do %>
                        <.link
                          href={~p"/downloads/#{order.id}"}
                          class="btn btn-sm btn-primary"
                        >
                          Download
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    orders = Orders.list_user_orders(user.id)

    socket =
      socket
      |> assign(:orders, orders)
      |> assign(:page_title, "Order History")

    {:ok, socket}
  end

  @impl true
  def handle_info(%{event: "order_updated", payload: updated_order}, socket) do
    # Update the order in the list if it exists
    updated_orders = Enum.map(socket.assigns.orders, fn order ->
      if order.id == updated_order.id do
        # Get the full order with all preloads for proper display
        Orders.get_order!(updated_order.id)
      else
        order
      end
    end)

    {:noreply, assign(socket, :orders, updated_orders)}
  end
end
