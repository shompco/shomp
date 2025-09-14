defmodule ShompWeb.AdminLive.OrderShow do
  use ShompWeb, :live_view

  alias Shomp.Orders

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(%{"immutable_id" => immutable_id}, _session, socket) do
    # Find order by immutable_id only
    order = Orders.get_order_by_immutable_id!(immutable_id)

    case order do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Order #{immutable_id} not found in database")
         |> assign(:order, nil)
         |> assign(:page_title, "Admin - Order #{immutable_id} (Not Found)")}

      order ->
        # Preload order items and products
        order_with_details = Shomp.Repo.preload(order, [
          order_items: :product,
          user: []
        ])

        # Manually fetch store data and categories for each product
        order_with_stores = %{order_with_details |
          order_items: Enum.map(order_with_details.order_items, fn order_item ->
            store = Shomp.Stores.get_store_by_store_id(order_item.product.store_id)

            # Load platform category if it exists
            product_with_store = %{order_item.product | store: store}
            product_with_categories = if product_with_store.category_id do
              case Shomp.Repo.get(Shomp.Categories.Category, product_with_store.category_id) do
                nil -> product_with_store
                category -> %{product_with_store | category: category}
              end
            else
              product_with_store
            end

            # Load custom category if it exists
            product_with_all = if product_with_categories.custom_category_id do
              case Shomp.Repo.get(Shomp.Categories.Category, product_with_categories.custom_category_id) do
                nil -> product_with_categories
                custom_category -> %{product_with_categories | custom_category: custom_category}
              end
            else
              product_with_categories
            end

            %{order_item | product: product_with_all}
          end)
        }

        {:ok,
         socket
         |> assign(:order, order_with_stores)
         |> assign(:page_title, "Admin - Order #{order.immutable_id}")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-12">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-base-content">Admin - Order Details</h1>
              <p class="text-lg text-base-content/70 mt-2">
                <%= if @order do %>
                  Order <%= @order.immutable_id %>
                <% else %>
                  Order Not Found
                <% end %>
              </p>
            </div>
            <div class="flex gap-2">
              <a href={~p"/admin"} class="btn btn-outline">
                ← Back to Admin
              </a>
              <%= if @order do %>
                <a href={~p"/admin/support?order_id=#{@order.immutable_id}"} class="btn btn-primary">
                  🎫 View Support
                </a>
              <% end %>
            </div>
          </div>
        </div>

        <%= if @order do %>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Main Content -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Order Summary -->
            <div class="bg-base-100 shadow rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-medium text-base-content">Order Summary</h2>
              </div>
              <div class="px-6 py-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <h3 class="text-sm font-medium text-base-content/70 mb-2">Order Information</h3>
                    <dl class="space-y-2">
                      <div>
                        <dt class="text-sm text-base-content/70">Order ID</dt>
                        <dd class="text-sm font-medium text-base-content"><%= @order.immutable_id %></dd>
                      </div>
                      <div>
                        <dt class="text-sm text-base-content/70">Date</dt>
                        <dd class="text-sm font-medium text-base-content">
                          <%= Calendar.strftime(@order.inserted_at, "%B %d, %Y at %I:%M %p") %>
                        </dd>
                      </div>
                      <div>
                        <dt class="text-sm text-base-content/70">Status</dt>
                        <dd class="text-sm font-medium text-base-content">
                          <span class="badge badge-success">
                            <%= String.capitalize(@order.status) %>
                          </span>
                        </dd>
                      </div>
                    </dl>
                  </div>
                  <div>
                    <h3 class="text-sm font-medium text-base-content/70 mb-2">Payment Information</h3>
                    <dl class="space-y-2">
                      <div>
                        <dt class="text-sm text-base-content/70">Total Amount</dt>
                        <dd class="text-lg font-bold text-base-content">$<%= Decimal.to_string(@order.total_amount) %></dd>
                      </div>
                      <div>
                        <dt class="text-sm text-base-content/70">Stripe Session</dt>
                        <dd class="text-sm font-mono text-base-content/60"><%= @order.stripe_session_id %></dd>
                      </div>
                    </dl>
                  </div>
                </div>
              </div>
            </div>

            <!-- Order Items -->
            <div class="bg-base-100 shadow rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h2 class="text-lg font-medium text-base-content">Order Items</h2>
              </div>
              <div class="px-6 py-4">
                <div class="space-y-4">
                  <%= for order_item <- @order.order_items do %>
                    <div class="flex items-center space-x-4 p-4 border border-base-300 rounded-lg">
                      <div class="flex-shrink-0">
                        <%= if order_item.product.image_thumb do %>
                          <img
                            src={"/uploads/products/#{order_item.product.id}/#{order_item.product.image_thumb}"}
                            alt={order_item.product.title}
                            class="w-16 h-16 object-cover rounded"
                          />
                        <% else %>
                          <div class="w-16 h-16 bg-base-300 rounded flex items-center justify-center">
                            <span class="text-base-content/50">No Image</span>
                          </div>
                        <% end %>
                      </div>
                      <div class="flex-1 min-w-0">
                        <h3 class="text-sm font-medium text-base-content truncate">
                          <%= order_item.product.title %>
                        </h3>
                        <p class="text-sm text-base-content/70">
                          by <%= order_item.product.store.name %>
                        </p>
                        <p class="text-sm text-base-content/70">
                          Quantity: <%= order_item.quantity %>
                        </p>
                      </div>
                      <div class="flex-shrink-0 text-right">
                        <p class="text-sm font-medium text-base-content">
                          $<%= Decimal.to_string(order_item.price) %>
                        </p>
                        <p class="text-xs text-base-content/70">
                          Total: $<%= Decimal.to_string(Decimal.mult(order_item.price, order_item.quantity)) %>
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <!-- Sidebar -->
          <div class="space-y-6">
            <!-- Customer Information -->
            <div class="bg-base-100 shadow rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h3 class="text-lg font-medium text-base-content">Customer Information</h3>
              </div>
              <div class="px-6 py-4">
                <dl class="space-y-2">
                  <div>
                    <dt class="text-sm text-base-content/70">Name</dt>
                    <dd class="text-sm font-medium text-base-content">
                      <%= @order.user.name || @order.user.email %>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/70">Email</dt>
                    <dd class="text-sm font-medium text-base-content">
                      <a href={"mailto:#{@order.user.email}"} class="link link-primary">
                        <%= @order.user.email %>
                      </a>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/70">Username</dt>
                    <dd class="text-sm font-medium text-base-content">
                      <%= @order.user.username || "Not set" %>
                    </dd>
                  </div>
                </dl>
              </div>
            </div>

            <!-- Order Actions -->
            <div class="bg-base-100 shadow rounded-lg">
              <div class="px-6 py-4 border-b border-base-300">
                <h3 class="text-lg font-medium text-base-content">Admin Actions</h3>
              </div>
              <div class="px-6 py-4 space-y-3">
                <a href={~p"/admin/support?order_id=#{@order.immutable_id}"} class="btn btn-primary w-full">
                  🎫 View Support Tickets
                </a>
                <a href={~p"/admin/users"} class="btn btn-outline w-full">
                  👤 View Customer Profile
                </a>
                <button class="btn btn-outline w-full" disabled>
                  📧 Send Email
                </button>
              </div>
            </div>
          </div>
        </div>
        <% else %>
        <!-- Order Not Found -->
        <div class="bg-base-100 shadow rounded-lg">
          <div class="px-6 py-12 text-center">
            <div class="mx-auto w-12 h-12 bg-error/10 rounded-full flex items-center justify-center mb-4">
              <svg class="w-6 h-6 text-error" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-base-content mb-2">Order Not Found</h3>
            <p class="text-base-content/70 mb-4">
              The order you're looking for doesn't exist in the database.
            </p>
            <div class="flex justify-center gap-2">
              <a href={~p"/admin"} class="btn btn-primary">
                Back to Admin Dashboard
              </a>
            </div>
          </div>
        </div>
        <% end %>
      </div>
    </div>
    """
  end
end
