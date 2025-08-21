defmodule ShompWeb.PaymentLive.Success do
  use ShompWeb, :live_view

  alias Shomp.Payments
  alias Shomp.Repo
  alias Phoenix.PubSub
  alias ShompWeb.Endpoint

  def mount(%{"session_id" => session_id} = params, _session, socket) do
    # Get payment details - try both session_id and payment_intent_id
    payment = Payments.get_payment_by_stripe_id(session_id) || 
              Payments.get_payment_by_payment_intent_id(session_id)
    
    # Get order details for review tracking (handle case where order might not exist yet)
    order = if payment do
      try do
        # Try to find order by the payment's stripe ID (which could be either session or payment intent)
        order = Shomp.Orders.get_order_by_stripe_session_id!(payment.stripe_payment_id)
        # Preload the associations if order exists
        Repo.preload(order, [order_items: :product])
      rescue
        Ecto.NoResultsError -> nil  # Order not created yet (webhook might be delayed)
      end
    else
      nil
    end
    
    # Subscribe to order updates for this session
    if payment && !order do
      PubSub.subscribe(Shomp.PubSub, "order_created:#{session_id}")
    end
    
    socket = 
      socket
      |> assign(:session_id, session_id)
      |> assign(:payment, payment)
      |> assign(:order, order)
      |> assign(:store_slug, params["store_slug"])
      |> assign(:page_title, "Payment Successful")

    {:ok, socket}
  end

  def handle_info({:order_created, order}, socket) do
    # Order was created! Update the UI with preloaded data
    {:noreply, assign(socket, :order, order)}
  end

  def handle_event("donate", %{"amount" => amount, "frequency" => frequency}, socket) do
            case Payments.create_donation_session(
          String.to_integer(amount),
          frequency,
          socket.assigns.store_slug,
          "#{Endpoint.url()}/payments/success?session_id={CHECKOUT_SESSION_ID}&store_slug=#{socket.assigns.store_slug}",
          "#{Endpoint.url()}/payments/cancel?store_slug=#{socket.assigns.store_slug}"
        ) do
      {:ok, session} ->
        {:noreply, redirect(socket, external: session.url)}
      {:error, _reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to create donation session. Please try again.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100">
              <svg class="h-6 w-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2 class="mt-6 text-3xl font-extrabold text-gray-900">
              Payment Successful!
            </h2>
            <p class="mt-2 text-sm text-gray-600">
              Thank you for your purchase. Your payment has been processed successfully.
            </p>
            
            <%= if @order do %>
              <div class="mt-4 p-4 bg-green-50 rounded-md border border-green-200">
                <h3 class="text-lg font-medium text-green-900 mb-2">Purchase Details</h3>
                <div class="space-y-2">
                  <%= for order_item <- @order.order_items do %>
                    <div class="flex justify-between items-center">
                      <span class="text-sm text-green-800">
                        <%= order_item.product.title %>
                      </span>
                      <span class="text-sm font-medium text-green-900">
                        $<%= Decimal.to_string(order_item.price) %>
                      </span>
                    </div>
                  <% end %>
                  <div class="border-t border-green-200 pt-2 mt-2">
                    <div class="flex justify-between items-center">
                      <span class="font-medium text-green-900">Total</span>
                      <span class="font-bold text-green-900">
                        $<%= Decimal.to_string(@order.total_amount) %>
                      </span>
                    </div>
                  </div>
                </div>
                
                <div class="mt-4 pt-3 border-t border-green-200">
                  <p class="text-sm text-green-700 mb-3">
                    Enjoy your purchase! You can now review this product.
                  </p>
                  <%= for order_item <- @order.order_items do %>
                    <a 
                      href={"/#{@store_slug}/products/#{order_item.product_id}/reviews/new"} 
                      class="inline-block bg-green-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-green-700 transition-colors"
                    >
                      Review <%= order_item.product.title %>
                    </a>
                  <% end %>
                </div>
              </div>
            <% else %>
              <%= if @payment do %>
                <div class="mt-4 p-4 bg-blue-50 rounded-md border border-blue-200">
                  <div class="flex items-center justify-center">
                    <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
                    <span class="ml-2 text-sm text-blue-700">Processing your order...</span>
                  </div>
                  <p class="text-xs text-blue-600 mt-2 text-center">
                    This may take a few moments. Please wait while we finalize your purchase.
                  </p>
                </div>
              <% end %>
            <% end %>
            
            <%= if @session_id do %>
              <div class="mt-4 p-3 bg-gray-50 rounded-md">
                <p class="text-xs text-gray-500">Session ID: <%= @session_id %></p>
              </div>
            <% end %>
          </div>

          <!-- Donation Section -->
          <div class="mt-8 pt-6 border-t border-gray-200">
            <h3 class="text-lg font-medium text-gray-900 text-center mb-4">
              Donate to Shomp
            </h3>
            <div class="grid grid-cols-2 gap-3">
              <button phx-click="donate" phx-value-amount="5" phx-value-frequency="one_time" class="btn btn-outline btn-sm w-full">Donate $5 (One-Time)</button>
              <button phx-click="donate" phx-value-amount="5" phx-value-frequency="monthly" class="btn btn-outline btn-sm w-full">Donate $5 (Monthly)</button>
              <button phx-click="donate" phx-value-amount="10" phx-value-frequency="one_time" class="btn btn-outline btn-sm w-full">Donate $10 (One-Time)</button>
              <button phx-click="donate" phx-value-amount="10" phx-value-frequency="monthly" class="btn btn-outline btn-sm w-full">Donate $10 (Monthly)</button>
              <button phx-click="donate" phx-value-amount="25" phx-value-frequency="one_time" class="btn btn-outline btn-sm w-full">Donate $25 (One-Time)</button>
              <button phx-click="donate" phx-value-amount="25" phx-value-frequency="monthly" class="btn btn-outline btn-sm w-full">Donate $25 (Monthly)</button>
            </div>
            <div class="text-center">
              <p class="text-xs text-gray-500 mt-3">Donations help keep Shomp running and support ongoing development.</p>
            </div>
          </div>

          <div class="mt-8">
            <div class="text-center space-y-3">
              <a href="/" class="btn btn-primary w-full">Return to Home</a>
              <%= if @store_slug do %>
                <a href={"/#{@store_slug}"} class="btn btn-outline w-full">Return to Store</a>
              <% end %>
              <a href="/dashboard" class="btn btn-outline w-full">Go to Dashboard</a>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
