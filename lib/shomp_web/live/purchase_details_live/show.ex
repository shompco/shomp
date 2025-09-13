defmodule ShompWeb.PurchaseDetailsLive.Show do
  use ShompWeb, :live_view

  alias Shomp.UniversalOrders
  alias Shomp.Downloads
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

          # Get download tokens for digital products
          download_tokens = get_download_tokens_for_order_items(order_items, user.id)

          # Subscribe to universal order updates
          Phoenix.PubSub.subscribe(Shomp.PubSub, "universal_orders")

          socket =
            socket
            |> assign(:universal_order, universal_order)
            |> assign(:download_tokens, download_tokens)
            |> assign(:max_downloads, get_max_downloads())
            |> assign(:page_title, "Purchase ##{universal_order.universal_order_id}")

          # Subscribe to download events when connected
          if connected?(socket) do
            Phoenix.PubSub.subscribe(Shomp.PubSub, "downloads:#{user.id}")
          end

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
                          <%= if order_item.product.type == "digital" do %>
                            <div class="mt-2">
                              <%= case get_download_info(order_item.product.id, @download_tokens) do %>
                                <% {:ok, download} -> %>
                                  <div class="flex items-center space-x-2">
                                    <.link
                                      href={~p"/downloads/#{download.token}"}
                                      class="btn btn-primary btn-sm"
                                      target="_blank"
                                    >
                                      📥 Download File
                                    </.link>
                                    <span class="text-xs text-base-content/60">
                                      (<%= download.download_count %>/<%= @max_downloads %> downloads used)
                                    </span>
                                  </div>
                                  <p class="text-xs text-warning mt-1">
                                    Expires: <%= Calendar.strftime(download.expires_at, "%b %d, %Y at %I:%M %p") %>
                                  </p>
                                <% {:error, :not_found} -> %>
                                  <div class="flex items-center space-x-2">
                                    <button
                                      phx-click="create_download"
                                      phx-value-product_id={order_item.product.id}
                                      class="btn btn-primary btn-sm"
                                    >
                                      📥 Generate Download Link
                                    </button>
                                  </div>
                                <% {:error, :expired} -> %>
                                  <span class="text-xs text-error">Download link expired</span>
                                <% {:error, :limit_exceeded} -> %>
                                  <span class="text-xs text-error">Download limit exceeded</span>
                              <% end %>
                            </div>
                          <% end %>
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

  @impl true
  def handle_event("create_download", %{"product_id" => product_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    product_id_int = String.to_integer(product_id)

    # Check if there's already a download for this product
    case get_download_info(product_id_int, socket.assigns.download_tokens) do
      {:error, :limit_exceeded} ->
        {:noreply, put_flash(socket, :error, "Download limit exceeded for this product")}

      {:error, :not_found} ->
        # Find the order item for this specific purchase
        order_item = socket.assigns.universal_order.universal_order_items
        |> Enum.find(fn item -> item.product.id == product_id_int end)

        case order_item do
          nil ->
            {:noreply, put_flash(socket, :error, "Product not found")}

          item ->
            # Create download for this specific order item (each purchase gets its own download record)
            case Downloads.create_download_for_order_item(item, user_id) do
              {:ok, download} ->
                # Update the download tokens in the socket
                new_tokens = Map.put(socket.assigns.download_tokens, product_id_int, {:ok, download})

                {:noreply,
                 socket
                 |> put_flash(:info, "Download link generated successfully!")
                 |> assign(:download_tokens, new_tokens)}

              {:error, reason} ->
                {:noreply, put_flash(socket, :error, "Failed to create download link: #{inspect(reason)}")}
            end
        end

      {:ok, _download} ->
        {:noreply, put_flash(socket, :error, "Download link already exists for this product")}
    end
  end

  @impl true
  def handle_info(%{event: "download_updated", payload: %{download: download}}, socket) do
    IO.puts("=== RECEIVED DOWNLOAD UPDATE EVENT ===")
    IO.puts("Download ID: #{download.id}")
    IO.puts("Product Immutable ID: #{download.product_immutable_id}")
    IO.puts("Order Item ID: #{download.order_item_id}")
    IO.puts("Download Count: #{download.download_count}")

    # Find the matching order item by product
    product_id = socket.assigns.universal_order.universal_order_items
    |> Enum.find(fn item -> 
      item.product.immutable_id == download.product_immutable_id
    end)
    |> case do
      nil -> nil
      item -> item.product.id
    end

    IO.puts("Found Product ID: #{inspect(product_id)}")

    case product_id do
      nil ->
        IO.puts("❌ No matching product found for download update")
        {:noreply, socket}
      id ->
        # Update the download token for this product
        new_tokens = Map.put(socket.assigns.download_tokens, id, {:ok, download})
        IO.puts("✅ Updated download tokens for product #{id}")

        {:noreply, assign(socket, :download_tokens, new_tokens)}
    end
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Helper functions

  defp get_download_tokens_for_order_items(order_items, user_id) do
    # Get all digital products from the order
    digital_products = order_items
    |> Enum.filter(fn item -> item.product.type == "digital" end)

    IO.puts("=== DOWNLOAD TOKENS DEBUG ===")
    IO.puts("Digital products count: #{length(digital_products)}")
    IO.puts("User ID: #{user_id}")

    # Get download tokens for each order item (each purchase gets its own download record)
    digital_products
    |> Enum.map(fn order_item ->
      product_id = order_item.product.id
      
      IO.puts("Processing order item:")
      IO.puts("  Order Item ID: #{order_item.id}")
      IO.puts("  Product ID: #{product_id}")
      IO.puts("  Product Immutable ID: #{order_item.product.immutable_id}")
      
      # Get download record for this product (most recent one)
      downloads = Downloads.list_user_downloads(user_id)
      |> Enum.filter(fn download -> 
        download.product_immutable_id == order_item.product.immutable_id
      end)
      |> Enum.sort_by(fn download -> download.inserted_at end, :desc) # Most recent first
      
      IO.puts("  Found downloads: #{length(downloads)}")
      for {download, index} <- Enum.with_index(downloads) do
        IO.puts("    Download #{index + 1}:")
        IO.puts("      ID: #{download.id}")
        IO.puts("      Product Immutable ID: #{download.product_immutable_id}")
        IO.puts("      Order Item ID: #{download.order_item_id}")
        IO.puts("      Download Count: #{download.download_count}")
        IO.puts("      Valid: #{Downloads.Download.valid?(download)}")
        IO.puts("      Within Limit: #{Downloads.Download.within_limit?(download, get_max_downloads())}")
      end
      
      case downloads do
        [] -> 
          IO.puts("  Result: {:error, :not_found}")
          {product_id, {:error, :not_found}}
        [download | _] -> 
          # Check if the download is still valid and within limits
          cond do
            not Downloads.Download.valid?(download) -> 
              # If expired, show as not found so user can create a new one
              IO.puts("  Result: {:error, :not_found} (expired)")
              {product_id, {:error, :not_found}}
            not Downloads.Download.within_limit?(download, get_max_downloads()) -> 
              # If limit exceeded, show limit exceeded (don't allow new downloads)
              IO.puts("  Result: {:error, :limit_exceeded}")
              {product_id, {:error, :limit_exceeded}}
            true -> 
              IO.puts("  Result: {:ok, download}")
              {product_id, {:ok, download}}
          end
      end
    end)
    |> Enum.into(%{})
  end

  defp get_download_info(product_id, download_tokens) do
    case Map.get(download_tokens, product_id) do
      nil -> {:error, :not_found}
      {:ok, download} ->
        cond do
          not Downloads.Download.valid?(download) -> {:error, :expired}
          not Downloads.Download.within_limit?(download, get_max_downloads()) -> {:error, :limit_exceeded}
          true -> {:ok, download}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_max_downloads do
    # Set to 5 downloads maximum for security
    5
  end
end
