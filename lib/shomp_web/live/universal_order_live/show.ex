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
          preload: [product: :store]
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
                <!-- Print Shipping Label -->
                <%= if @universal_order.shipping_cost && Decimal.gt?(@universal_order.shipping_cost, Decimal.new("0")) do %>
                  <!-- DEBUG: Shipping cost exists and is > 0 -->
                  <div>
                    <h3 class="text-md font-medium text-base-content mb-3">Shipping Label</h3>
                    <div class="space-y-3">
                      <button
                        type="button"
                        class="btn btn-primary"
                        phx-click="print_shipping_label"
                        onclick="console.log('=== PRINT SHIPPING LABEL BUTTON CLICKED ==='); console.log('Timestamp:', new Date().toISOString());"
                      >
                        📦 Print Shipping Label
                      </button>
                      <p class="text-sm text-base-content/60">
                        When you print a shipping label you will get a PDF in a new tab. The buyer will get a notification that a label has been printed.
                      </p>
                    </div>
                  </div>
                <% else %>
                  <!-- DEBUG: Button not visible -->
                  <div class="bg-warning/10 border border-warning/20 rounded-lg p-4">
                    <h3 class="text-md font-medium text-warning mb-2">Debug: Print Shipping Label Button Not Visible</h3>
                    <p class="text-sm text-warning/80">
                      Shipping Cost: <%= inspect(@universal_order.shipping_cost) %><br/>
                      Condition Check: <%= if @universal_order.shipping_cost, do: "shipping_cost exists", else: "shipping_cost is nil" %>
                      <%= if @universal_order.shipping_cost && Decimal.gt?(@universal_order.shipping_cost, Decimal.new("0")), do: "AND > 0", else: "BUT NOT > 0" %>
                    </p>
                  </div>
                <% end %>

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
                <!-- Payment Breakdown -->
                <div class="border-t border-base-300 pt-4 mt-4">
                  <h3 class="text-sm font-medium text-base-content mb-3">Payment Breakdown</h3>

                  <!-- Product Total -->
                  <div class="flex justify-between text-sm">
                    <span class="text-base-content/70">Product Total</span>
                    <span>$<%= Decimal.to_string(Decimal.sub(@universal_order.total_amount, Decimal.add(@universal_order.platform_fee_amount || Decimal.new("0"), @universal_order.shipping_cost || Decimal.new("0"))), :normal) %></span>
                  </div>

                  <!-- Donation -->
                  <%= if Decimal.gt?(@universal_order.platform_fee_amount, Decimal.new("0")) do %>
                    <div class="flex justify-between text-sm">
                      <span class="text-base-content/70">Shomp Donation (5%)</span>
                      <span class="text-success">$<%= Decimal.to_string(@universal_order.platform_fee_amount, :normal) %></span>
                    </div>
                  <% end %>

                  <!-- Shipping -->
                  <%= if @universal_order.shipping_cost && Decimal.gt?(@universal_order.shipping_cost, Decimal.new("0")) do %>
                    <div class="flex justify-between text-sm">
                      <span class="text-base-content/70">Shipping (<%= @universal_order.shipping_method_name || @universal_order.carrier || "Standard" %>)</span>
                      <span>$<%= Decimal.to_string(@universal_order.shipping_cost, :normal) %></span>
                    </div>
                  <% end %>

                  <!-- Total Amount -->
                  <div class="flex justify-between font-semibold border-t border-base-300 pt-2 mt-2">
                    <span>Total Amount</span>
                    <span>$<%= Decimal.to_string(@universal_order.total_amount, :normal) %></span>
                  </div>
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

    <script>
      // Handle opening shipping label PDF in new tab
      window.addEventListener("phx:open_label_pdf", (e) => {
        console.log("=== PDF OPEN EVENT RECEIVED ===");
        console.log("Event detail:", e.detail);
        console.log("Label URL:", e.detail.url);
        console.log("Opening PDF in new tab...");

        if (e.detail.url && e.detail.url.trim() !== "") {
          window.open(e.detail.url, '_blank');
          console.log("PDF window opened successfully");
        } else {
          console.error("No valid label URL provided! URL:", e.detail.url);
        }
      });
    </script>
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
  def handle_event("update_status", params, socket) do
    IO.puts("=== UPDATE STATUS EVENT ===")
    IO.puts("Params: #{inspect(params)}")

    universal_order = socket.assigns.universal_order
    status = params["shipping_status"]
    tracking = params["tracking_number"] || ""
    carrier = params["carrier"] || ""

    IO.puts("Status: #{status}")
    IO.puts("Tracking: #{tracking}")
    IO.puts("Carrier: #{carrier}")

    # Build attrs based on what's provided
    attrs = %{shipping_status: status}
    attrs = if tracking != "", do: Map.put(attrs, :tracking_number, tracking), else: attrs
    attrs = if carrier != "", do: Map.put(attrs, :carrier, carrier), else: attrs

    case UniversalOrders.update_universal_order(universal_order, attrs) do
      {:ok, updated_order} ->
        # Broadcast the update
        Phoenix.PubSub.broadcast(Shomp.PubSub, "universal_orders", %{
          event: "universal_order_updated",
          payload: updated_order
        })

        status_form = to_form(%{"shipping_status" => updated_order.shipping_status}, as: :status)
        show_tracking = updated_order.shipping_status in ["label_printed", "shipped"]

        {:noreply,
         socket
         |> put_flash(:info, "Order status updated successfully")
         |> assign(:universal_order, updated_order)
         |> assign(:status_form, status_form)
         |> assign(:show_tracking_input, show_tracking)}

      {:error, _changeset} ->
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
  def handle_event("print_shipping_label", _params, socket) do
    IO.puts("=== PRINT SHIPPING LABEL EVENT RECEIVED ===")
    IO.puts("Socket assigns: #{inspect(socket.assigns)}")

    universal_order = socket.assigns.universal_order

    IO.puts("=== PRINT SHIPPING LABEL EVENT HANDLER ===")
    IO.puts("Order ID: #{universal_order.universal_order_id}")
    IO.puts("Customer: #{universal_order.customer_name}")
    IO.puts("Customer Email: #{universal_order.customer_email}")
    IO.puts("Shipping Cost: #{universal_order.shipping_cost}")
    IO.puts("Order Items Count: #{length(universal_order.universal_order_items)}")
    IO.puts("Timestamp: #{DateTime.utc_now()}")

    # Get the first order item to get product details
    case universal_order.universal_order_items do
      [order_item | _] ->
        product = order_item.product

        IO.puts("=== PRODUCT DETAILS ===")
        IO.puts("Product Title: #{product.title}")
        IO.puts("Product Type: #{product.type}")
        IO.puts("Store ZIP Code: #{product.store.shipping_zip_code}")
        IO.puts("Product Dimensions: #{product.length}x#{product.width}x#{product.height}")
        IO.puts("Product Weight: #{product.weight} #{product.weight_unit}")

        # Create from address using store ZIP code
        from_address = %{
          name: "Store",
          street1: "123 Main St",
          city: "Store",
          state: "NY",
          zip: product.store.shipping_zip_code || "10001",
          country: "US"
        }

        # Create to address from order
        to_address = %{
          name: universal_order.customer_name,
          street1: universal_order.shipping_address_line1,
          street2: universal_order.shipping_address_line2,
          city: universal_order.shipping_address_city,
          state: universal_order.shipping_address_state,
          zip: universal_order.shipping_address_postal_code,
          country: universal_order.shipping_address_country
        }

        # Create parcel from product dimensions
        parcel = %{
          length: product.length || 6.0,
          width: product.width || 4.0,
          height: product.height || 2.0,
          weight: product.weight || 1.0,
          weight_unit: product.weight_unit || "lb",
          distance_unit: product.distance_unit || "in"
        }

        IO.puts("=== ADDRESS DETAILS ===")
        IO.puts("From Address: #{inspect(from_address)}")
        IO.puts("To Address: #{inspect(to_address)}")
        IO.puts("Parcel: #{inspect(parcel)}")

        # Use the actual shipping method from the order
        service_token = case universal_order.shipping_method_name do
          nil ->
            IO.puts("No shipping method name found, using carrier: #{universal_order.carrier}")
            case universal_order.carrier do
              "UPS" -> "ups_ground"
              "USPS" -> "usps_ground_advantage"
              "FedEx" -> "fedex_ground"
              _ ->
                IO.puts("ERROR: No valid shipping method found!")
                {:error, :no_shipping_method}
            end
          method_name ->
            IO.puts("Using shipping method name: #{method_name}")
            # Convert method name to service token (remove special characters for matching)
            clean_method = method_name
            |> String.downcase()
            |> String.replace(~r/[®™©]/, "")  # Remove trademark symbols
            |> String.replace(~r/\s+/, " ")   # Normalize whitespace
            |> String.trim()

            IO.puts("Cleaned method name: '#{clean_method}'")

            case clean_method do
              method when method in ["ups ground", "ups_ground"] -> "ups_ground"
              method when method in ["ups next day air", "ups_next_day_air"] -> "ups_ground_saver"
              method when method in ["ups 2nd day air", "ups_2nd_day_air"] -> "ups_2nd_day_air"
              method when method in ["ups 3 day select", "ups_3_day_select"] -> "ups_3_day_select"
              method when method in ["usps priority", "usps_priority"] -> "usps_priority"
              method when method in ["usps ground advantage", "usps_ground_advantage"] -> "usps_ground_advantage"
              method when method in ["fedex ground", "fedex_ground"] -> "fedex_ground"
              method when method in ["fedex 2 day", "fedex_2_day"] -> "fedex_2_day"
              method when method in ["fedex overnight", "fedex_overnight"] -> "fedex_overnight"
              _ ->
                IO.puts("ERROR: Unknown method name: '#{method_name}' (cleaned: '#{clean_method}')")
                {:error, :unknown_shipping_method}
            end
        end

        case service_token do
          {:error, reason} ->
            IO.puts("=== SHIPPING METHOD ERROR ===")
            IO.puts("Error: #{inspect(reason)}")
            {:noreply,
             socket
             |> put_flash(:error, "Cannot generate label: #{inspect(reason)}")}

          service_token ->
            # Check if we already have a label URL saved
            case universal_order.label_url do
              nil ->
                IO.puts("=== NO EXISTING LABEL FOUND - GENERATING NEW ONE ===")
                IO.puts("=== CALLING SHIPPO API ===")
                IO.puts("Service Token: #{service_token}")

                case Shomp.ShippoApi.generate_label(from_address, to_address, parcel, service_token) do
                  {:ok, %{label_url: label_url, tracking_number: tracking_number}} ->
                    IO.puts("=== SHIPPO API SUCCESS ===")
                    IO.puts("Label URL: #{label_url}")
                    IO.puts("Tracking Number: #{tracking_number}")

                    # Update the order with tracking number and label URL
                    case UniversalOrders.update_universal_order(universal_order, %{
                      tracking_number: tracking_number,
                      shipping_status: "label_printed",
                      label_url: label_url
                    }) do
                      {:ok, updated_order} ->
                        IO.puts("=== ORDER UPDATED ===")
                        IO.puts("Updated order with tracking number, status, and label URL")

                        # Send JavaScript to open PDF in new tab
                        IO.puts("=== SENDING PDF OPEN EVENT ===")
                        IO.puts("Label URL to open: #{label_url}")
                        IO.puts("Is label_url nil? #{is_nil(label_url)}")

                        # Update the socket with the new order data for real-time UI update
                        updated_socket = assign(socket, :universal_order, updated_order)

                        {:noreply,
                         updated_socket
                         |> put_flash(:info, "Shipping label generated successfully!")
                         |> push_event("open_label_pdf", %{url: label_url})}

                      {:error, _changeset} ->
                        IO.puts("=== ORDER UPDATE FAILED ===")
                        {:noreply,
                         socket
                         |> put_flash(:error, "Label generated but failed to update order status")}
                    end

                  {:error, reason} ->
                    IO.puts("=== SHIPPO API ERROR ===")
                    IO.puts("Error: #{inspect(reason)}")

                    {:noreply,
                     socket
                     |> put_flash(:error, "Failed to generate shipping label: #{inspect(reason)}")}
                end

              existing_label_url ->
                IO.puts("=== EXISTING LABEL FOUND ===")
                IO.puts("Label URL: #{existing_label_url}")
                IO.puts("Opening existing label...")

                {:noreply,
                 socket
                 |> put_flash(:info, "Opening existing shipping label...")
                 |> push_event("open_label_pdf", %{url: existing_label_url})}
            end
        end

      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "No order items found")}
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
