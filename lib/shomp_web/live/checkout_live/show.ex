defmodule ShompWeb.CheckoutLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Products
  alias Shomp.Payments

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(%{"product_id" => product_id}, _session, socket) do
    product = Products.get_product_with_store!(product_id)
    
    socket = 
      socket
      |> assign(:product, product)
      |> assign(:page_title, "Checkout - #{product.title}")

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
      "http://localhost:4000/payments/success?session_id={CHECKOUT_SESSION_ID}&store_slug=#{product.store.slug}",
      "http://localhost:4000/payments/cancel?store_slug=#{product.store.slug}"
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

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-white shadow-lg rounded-lg overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-4 border-b border-gray-200">
            <h1 class="text-2xl font-bold text-gray-900">Checkout</h1>
            <p class="text-gray-600">Complete your purchase</p>
          </div>

          <!-- Product Details -->
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

          <!-- Checkout Button -->
          <div class="px-6 py-6 border-t border-gray-200">
            <button
              phx-click="checkout"
              phx-disable-with="Creating checkout..."
              class="w-full btn btn-primary btn-lg"
            >
              Proceed to Payment - $<%= @product.price %>
            </button>
            
            <div class="mt-4 text-center">
              <p class="text-sm text-gray-500">
                You'll be redirected to Stripe to complete your payment securely
              </p>
            </div>
          </div>
        </div>

        <!-- Back to Product -->
        <div class="mt-6 text-center">
          <.link
            navigate={~p"/#{@product.store.slug}/products/#{@product.id}"}
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
