defmodule ShompWeb.CheckoutLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Products
  alias Shomp.Payments
  alias Shomp.ShippingCalculator
  alias ShompWeb.Endpoint

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  def mount(%{"product_id" => product_id}, _session, socket) do
    product = Products.get_product_with_store!(product_id)

    # Initialize shipping form
    shipping_form = to_form(%{
      "name" => "",
      "street1" => "",
      "city" => "",
      "state" => "",
      "zip" => "",
      "country" => "US"
    })

    socket =
      socket
      |> assign(:product, product)
      |> assign(:page_title, "Checkout - #{product.title}")
      |> assign(:shipping_form, shipping_form)
      |> assign(:shipping_options, [])
      |> assign(:selected_shipping_option, nil)
      |> assign(:shipping_cost, 0.0)
      |> assign(:shipping_loading, false)

    {:ok, socket}
  end

  def handle_event("checkout", _params, socket) do
    IO.puts("=== CHECKOUT BUTTON CLICKED ===")
    IO.puts("Product ID: #{socket.assigns.product.id}")
    IO.puts("Product Title: #{socket.assigns.product.title}")
    IO.puts("User ID: #{socket.assigns.current_scope.user.id}")

    product = socket.assigns.product

    IO.puts("Creating Stripe checkout session...")

    # Create Stripe checkout session
    case Payments.create_checkout_session(
      product.id,
      socket.assigns.current_scope.user.id,
      "#{Endpoint.url()}/payments/success?session_id={CHECKOUT_SESSION_ID}&store_slug=#{product.store.slug}",
      "#{Endpoint.url()}/payments/cancel?store_slug=#{product.store.slug}"
    ) do
      {:ok, session, _payment} ->
        IO.puts("Checkout session created successfully: #{session.id}")
        IO.puts("Redirecting to: #{session.url}")
        # Redirect to Stripe Checkout
        {:noreply, redirect(socket, external: session.url)}

      {:error, :no_stripe_product} ->
        IO.puts("Error: No Stripe product found")
        {:noreply,
         socket
         |> put_flash(:error, "This product is not available for purchase at the moment. Please contact support.")}

      {:error, reason} ->
        IO.puts("Error creating checkout session: #{inspect(reason)}")
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create checkout session. Please try again.")}
    end
  end

  def handle_event("validate_shipping_address", %{"shipping_address" => params}, socket) do
    # Update the form with new values
    shipping_form = to_form(params)

    socket =
      socket
      |> assign(:shipping_form, shipping_form)
      |> assign(:shipping_options, [])
      |> assign(:selected_shipping_option, nil)
      |> assign(:shipping_cost, 0.0)

    {:noreply, socket}
  end

  def handle_event("calculate_shipping", _params, socket) do
    if socket.assigns.product.type == "physical" do
      # Validate required fields
      required_fields = ["name", "street1", "city", "state", "zip"]
      missing_fields = Enum.filter(required_fields, fn field ->
        value = socket.assigns.shipping_form.params[field]
        is_nil(value) or String.trim(value) == ""
      end)

      if Enum.empty?(missing_fields) do
        # Calculate shipping
        shipping_address = %{
          name: socket.assigns.shipping_form.params["name"],
          street1: socket.assigns.shipping_form.params["street1"],
          city: socket.assigns.shipping_form.params["city"],
          state: socket.assigns.shipping_form.params["state"],
          zip: socket.assigns.shipping_form.params["zip"],
          country: socket.assigns.shipping_form.params["country"] || "US"
        }

        socket = assign(socket, :shipping_loading, true)

        # Send async message to calculate shipping
        send(self(), {:calculate_shipping, shipping_address})

        {:noreply, socket}
      else
        {:noreply,
         socket
         |> put_flash(:error, "Please fill in all required shipping address fields: #{Enum.join(missing_fields, ", ")}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_shipping_option", %{"shipping_option" => option_id}, socket) do
    selected_option = Enum.find(socket.assigns.shipping_options, &(&1.id == option_id))

    socket =
      socket
      |> assign(:selected_shipping_option, selected_option)
      |> assign(:shipping_cost, selected_option.cost)

    {:noreply, socket}
  end

  def handle_info({:calculate_shipping, shipping_address}, socket) do
    case ShippingCalculator.calculate_product_shipping(socket.assigns.product, shipping_address) do
      {:ok, shipping_options} ->
        socket =
          socket
          |> assign(:shipping_options, shipping_options)
          |> assign(:shipping_loading, false)

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> assign(:shipping_loading, false)
          |> put_flash(:error, "Failed to calculate shipping rates. Please try again.")

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Main Content -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Product Details -->
            <div class="bg-white shadow-lg rounded-lg overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200">
                <h1 class="text-2xl font-bold text-gray-900">Checkout</h1>
                <p class="text-gray-600">Complete your purchase</p>
              </div>

              <div class="px-6 py-6">
                <div class="flex items-start space-x-6">
                  <div class="flex-1">
                    <h2 class="text-xl font-semibold text-gray-900"><%= @product.title %></h2>
                    <p class="text-gray-600 mt-2"><%= @product.description %></p>
                    <div class="mt-4">
                      <span class="text-sm text-gray-500">Type:</span>
                      <span class="ml-2 text-sm font-medium text-gray-900"><%= @product.type %></span>
                    </div>
                    <%= if @product.file_path do %>
                      <div class="mt-2">
                        <span class="text-sm text-gray-500">File:</span>
                        <span class="ml-2 text-sm font-medium text-gray-900"><%= @product.file_path %></span>
                      </div>
                    <% end %>
                  </div>

                  <div class="text-right">
                    <div class="text-3xl font-bold text-gray-900">$<%= @product.price %></div>
                    <div class="text-sm text-gray-500">One-time purchase</div>
                  </div>
                </div>
              </div>

              <!-- Store Info -->
              <div class="px-6 py-4 bg-gray-50 border-t border-gray-200">
                <div class="flex items-center justify-between">
                  <div>
                    <span class="text-sm text-gray-500">Sold by:</span>
                    <span class="ml-2 text-sm font-medium text-gray-900"><%= @product.store.name %></span>
                  </div>
                  <div class="text-sm text-gray-500">
                    Store ID: <%= @product.store.slug %>
                  </div>
                </div>
              </div>
            </div>

            <!-- Shipping Section (only for physical products) -->
            <%= if @product.type == "physical" do %>
              <div class="bg-white shadow-lg rounded-lg overflow-hidden">
                <div class="px-6 py-4 border-b border-gray-200">
                  <h2 class="text-lg font-semibold text-gray-900">Shipping Information</h2>
                  <p class="text-sm text-gray-600">Enter your shipping address to calculate shipping costs</p>
                </div>

                <div class="px-6 py-6">
                  <.form for={@shipping_form} phx-change="validate_shipping_address" phx-submit="calculate_shipping">
                    <ShompWeb.ShippingComponents.shipping_address_form form={@shipping_form} />

                    <div class="mt-6">
                      <button
                        type="submit"
                        phx-disable-with="Calculating..."
                        class="btn btn-primary"
                      >
                        Calculate Shipping
                      </button>
                    </div>
                  </.form>

                  <!-- Shipping Options -->
                  <%= if not Enum.empty?(@shipping_options) do %>
                    <div class="mt-6">
                      <h3 class="text-md font-medium text-gray-900 mb-3">Select Shipping Method</h3>
                      <ShompWeb.ShippingComponents.shipping_options
                        shipping_options={@shipping_options}
                        selected_option={@selected_shipping_option}
                        loading={@shipping_loading}
                      />
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Order Summary -->
          <div class="lg:col-span-1">
            <div class="bg-white shadow-lg rounded-lg sticky top-8">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-medium text-gray-900">Order Summary</h3>
              </div>

              <div class="px-6 py-4">
                <div class="space-y-3">
                  <div class="flex justify-between text-sm">
                    <span class="text-gray-500"><%= @product.title %></span>
                    <span class="text-gray-900">$<%= @product.price %></span>
                  </div>

                  <ShompWeb.ShippingComponents.shipping_summary
                    shipping_cost={@shipping_cost}
                    subtotal={@product.price}
                  />
                </div>

                <div class="mt-6">
                  <button
                    phx-click="checkout"
                    phx-disable-with="Creating checkout..."
                    class="w-full btn btn-primary btn-lg"
                    disabled={@product.type == "physical" && @selected_shipping_option == nil}
                  >
                    <%= if @product.type == "physical" && @selected_shipping_option == nil do %>
                      Select Shipping Method
                    <% else %>
                      Proceed to Payment
                    <% end %>
                  </button>

                  <div class="mt-4 text-center">
                    <p class="text-sm text-gray-500">
                      You'll be redirected to Stripe to complete your payment securely
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Back to Product -->
        <div class="mt-6 text-center">
          <.link
            navigate={~p"/stores/#{@product.store.slug}/products/#{@product.id}"}
            class="text-indigo-600 hover:text-indigo-500"
          >
            ← Back to product
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
