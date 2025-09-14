defmodule ShompWeb.PaymentLive.Success do
  use ShompWeb, :live_view

  alias Shomp.Payments
  alias Shomp.Repo
  alias Phoenix.PubSub
  alias ShompWeb.Endpoint
  alias Shomp.Notifications
  alias Shomp.Products
  alias Shomp.Stores
  alias Shomp.Accounts

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

    # Subscribe to order updates for this session and payment processed events
    if payment && !order do
      PubSub.subscribe(Shomp.PubSub, "order_created:#{session_id}")
      PubSub.subscribe(Shomp.PubSub, "payment_processed:#{payment.stripe_payment_id}")
    end

    # Debug: Check if payment exists and create notifications as fallback
    if payment do
      IO.puts("DEBUG: Payment found for session_id #{session_id}, payment_id: #{payment.id}")

      # Check if notifications already exist for this payment (webhook might have created them)
      existing_notifications = Notifications.list_user_notifications(payment.user_id)
      |> Enum.filter(fn n ->
        n.metadata["order_id"] == to_string(payment.id) ||
        n.metadata["order_id"] == payment.id
      end)

      if length(existing_notifications) == 0 do
        IO.puts("DEBUG: No existing notifications found, creating fallback notifications")
        # Create notifications as fallback (webhook might not be running)
        notify_seller_of_purchase(payment)
        notify_buyer_of_purchase(payment)
      else
        IO.puts("DEBUG: Notifications already exist for this payment")
      end
    else
      IO.puts("DEBUG: No payment found for session_id #{session_id}")
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

  def handle_info({:payment_processed, _payment_intent_id}, socket) do
    # Payment was processed via webhook, reload the page to show updated data
    IO.puts("Payment processed via webhook, reloading success page data")
    # Reload the page to get the latest data
    {:noreply, push_navigate(socket, to: ~p"/payments/success?session_id=#{socket.assigns.session_id}")}
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
    <div class="min-h-screen bg-base-200 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <div class="bg-base-100 py-8 px-4 shadow sm:rounded-lg sm:px-10">
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-success/20">
              <svg class="h-6 w-6 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2 class="mt-6 text-3xl font-extrabold text-base-content">
              Payment Successful!
            </h2>
            <p class="mt-2 text-sm text-base-content/70">
              Thank you for your purchase. Your payment has been processed successfully.
            </p>

            <%= if @order do %>
              <div class="mt-4 p-4 bg-success/10 rounded-md border border-success/20">
                <h3 class="text-lg font-medium text-success mb-2">Purchase Details</h3>
                <div class="space-y-2">
                  <%= for order_item <- @order.order_items do %>
                    <div class="flex justify-between items-center">
                      <span class="text-sm text-base-content">
                        <%= order_item.product.title %>
                      </span>
                      <span class="text-sm font-medium text-base-content">
                        $<%= Decimal.to_string(order_item.price) %>
                      </span>
                    </div>
                  <% end %>
                  <div class="border-t border-base-300 pt-2 mt-2">
                    <div class="flex justify-between items-center">
                      <span class="font-medium text-base-content">Total</span>
                      <span class="font-bold text-base-content">
                        $<%= Decimal.to_string(@order.total_amount) %>
                      </span>
                    </div>
                  </div>
                </div>

                <div class="mt-4 pt-3 border-t border-base-300">
                  <p class="text-sm text-base-content/70 mb-3">
                    Enjoy your purchase! You can now review this product.
                  </p>
                  <%= for order_item <- @order.order_items do %>
                    <a
                      href={"/stores/#{@store_slug}/products/#{order_item.product_id}/reviews/new"}
                      class="inline-block btn btn-success btn-sm"
                    >
                      Review <%= order_item.product.title %>
                    </a>
                  <% end %>
                </div>
              </div>
            <% else %>
              <%= if @payment do %>
                <div class="mt-4 p-4 bg-info/10 rounded-md border border-info/20">
                  <div class="flex items-center justify-center">
                    <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-info"></div>
                    <span class="ml-2 text-sm text-info">Processing your order...</span>
                  </div>
                  <p class="text-xs text-info/70 mt-2 text-center">
                    This may take a few moments. Please wait while we finalize your purchase.
                  </p>
                </div>
              <% end %>
            <% end %>

            <%= if @session_id do %>
              <div class="mt-4 p-3 bg-base-200 rounded-md">
                <p class="text-xs text-base-content/60">Session ID: <%= @session_id %></p>
              </div>
            <% end %>
          </div>

          <!-- Donation Section -->
          <div class="mt-8 pt-6 border-t border-base-300">
            <h3 class="text-lg font-medium text-base-content text-center mb-4">
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
              <p class="text-xs text-base-content/60 mt-3">Donations help keep Shomp running and support ongoing development.</p>
            </div>
          </div>

          <div class="mt-8">
            <div class="text-center space-y-3">
              <a href="/" class="btn btn-primary w-full">Return to Home</a>
              <%= if @store_slug do %>
                <a href={"/stores/#{@store_slug}"} class="btn btn-outline w-full">Return to Store</a>
              <% end %>
              <a href="/dashboard" class="btn btn-outline w-full">Go to Dashboard</a>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private function to notify seller of purchase
  defp notify_seller_of_purchase(payment) do
    IO.puts("DEBUG: notify_seller_of_purchase called for payment #{payment.id}")
    try do
      # Get the product to find the seller
      product = Products.get_product!(payment.product_id)
      IO.puts("DEBUG: Found product #{product.id} for payment #{payment.id}")

      # Get the store to find the seller
      store = Stores.get_store!(product.store_id)
      IO.puts("DEBUG: Found store #{store.id} for product #{product.id}")

      # Get the buyer's name
      buyer = Accounts.get_user!(payment.user_id)
      buyer_name = buyer.name || buyer.email
      IO.puts("DEBUG: Found buyer #{buyer_name} for payment #{payment.id}")

      # Format the amount
      amount = Decimal.to_string(payment.amount, :normal)
      IO.puts("DEBUG: Amount is #{amount} for payment #{payment.id}")

      # Create notification for the seller
      case Notifications.notify_seller_new_order(store.user_id, payment.id, buyer_name, amount) do
        {:ok, notification} ->
          IO.puts("SUCCESS: Seller notification created for payment #{payment.id}, notification id: #{notification.id}")
        {:error, reason} ->
          IO.puts("ERROR: Failed to create seller notification: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("ERROR: Failed to notify seller for payment #{payment.id}: #{inspect(error)}")
    end
  end

  # Private function to notify buyer of purchase
  defp notify_buyer_of_purchase(payment) do
    IO.puts("DEBUG: notify_buyer_of_purchase called for payment #{payment.id}")
    try do
      # Format the amount
      amount = Decimal.to_string(payment.amount, :normal)
      IO.puts("DEBUG: Amount is #{amount} for payment #{payment.id}")

      # Create notification for the buyer
      case Notifications.notify_payment_received(payment.user_id, payment.id, amount) do
        {:ok, notification} ->
          IO.puts("SUCCESS: Buyer notification created for payment #{payment.id}, notification id: #{notification.id}")
        {:error, reason} ->
          IO.puts("ERROR: Failed to create buyer notification: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("ERROR: Failed to notify buyer for payment #{payment.id}: #{inspect(error)}")
    end
  end
end
