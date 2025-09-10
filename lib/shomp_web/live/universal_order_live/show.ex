defmodule ShompWeb.UniversalOrderLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.UniversalOrders

  @impl true
  def mount(%{"universal_order_id" => universal_order_id}, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    case UniversalOrders.get_universal_order_by_id(universal_order_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Order not found")
         |> push_navigate(to: ~p"/dashboard/purchases")}

      universal_order ->
        # Verify the order belongs to the current user
        if universal_order.user_id == user_id do
          # Preload the necessary associations
          universal_order = UniversalOrders.get_universal_order_by_id(universal_order.universal_order_id)

          {:ok, assign(socket,
            universal_order: universal_order,
            page_title: "Order Details - #{universal_order.universal_order_id}"
          )}
        else
          {:ok,
           socket
           |> put_flash(:error, "You don't have access to this order")
           |> push_navigate(to: ~p"/dashboard/purchases")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">Order Details</h1>
          <p class="text-lg text-base-content/70 mt-2">Order <%= @universal_order.universal_order_id %></p>
        </div>

        <!-- Order Information -->
        <div class="bg-base-100 shadow rounded-lg p-6 mb-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 class="text-lg font-semibold text-base-content mb-4">Order Information</h3>
              <div class="space-y-2">
                <div class="flex justify-between">
                  <span class="text-base-content/70">Order ID:</span>
                  <span class="font-mono text-sm"><%= @universal_order.universal_order_id %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Date:</span>
                  <span><%= Calendar.strftime(@universal_order.inserted_at, "%B %d, %Y at %I:%M %p") %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Customer:</span>
                  <span><%= @universal_order.customer_name %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Email:</span>
                  <span><%= @universal_order.customer_email %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Total Amount:</span>
                  <span class="font-semibold">$<%= Decimal.to_string(@universal_order.total_amount) %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/70">Status:</span>
                  <span class={get_status_badge_class(@universal_order.payment_status)}>
                    <%= String.capitalize(@universal_order.payment_status) %>
                  </span>
                </div>
              </div>
            </div>

            <div>
              <h3 class="text-lg font-semibold text-base-content mb-4">Order Items</h3>
              <div class="space-y-3">
                <%= for order_item <- @universal_order.universal_order_items do %>
                  <div class="flex items-center justify-between py-2 px-3 bg-base-200 rounded">
                    <div>
                      <p class="font-medium text-base-content"><%= order_item.product.title %></p>
                      <p class="text-sm text-base-content/70">
                        Store: <%= order_item.product.store.name %> • $<%= Decimal.to_string(order_item.price) %>
                      </p>
                    </div>
                    <div class="text-right">
                      <p class="font-semibold">$<%= Decimal.to_string(order_item.price) %></p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <!-- Payment Information -->
        <%= if @universal_order.payment_splits && length(@universal_order.payment_splits) > 0 do %>
          <div class="bg-base-100 shadow rounded-lg p-6 mb-6">
            <h3 class="text-lg font-semibold text-base-content mb-4">Payment Breakdown</h3>
            <div class="space-y-3">
              <%= for payment_split <- @universal_order.payment_splits do %>
                <div class="flex items-center justify-between py-2 px-3 bg-base-200 rounded">
                  <div>
                    <p class="font-medium text-base-content">Store Payment</p>
                    <p class="text-sm text-base-content/70">
                      Store ID: <%= payment_split.store_id %>
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="font-semibold">$<%= Decimal.to_string(payment_split.store_amount) %></p>
                    <%= if Decimal.gt?(payment_split.platform_fee_amount, 0) do %>
                      <p class="text-sm text-base-content/70">
                        Platform Fee: $<%= Decimal.to_string(payment_split.platform_fee_amount) %>
                      </p>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Order Actions -->
        <div class="flex justify-between items-center">
          <a href={~p"/dashboard/purchases"} class="btn btn-outline">
            ← Back to Purchases
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp get_status_badge_class(status) do
    case status do
      "paid" -> "badge badge-success"
      "pending" -> "badge badge-warning"
      "failed" -> "badge badge-error"
      "refunded" -> "badge badge-neutral"
      "partially_refunded" -> "badge badge-info"
      _ -> "badge badge-neutral"
    end
  end
end
