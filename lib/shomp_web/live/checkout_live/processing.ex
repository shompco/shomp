defmodule ShompWeb.CheckoutLive.Processing do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.UniversalOrders
  alias Phoenix.PubSub

  @impl true
  def mount(%{"payment_intent_id" => payment_intent_id}, _session, socket) do
    socket = assign(socket,
      payment_intent_id: payment_intent_id,
      status: "processing",
      attempts: 0
    )

    # Subscribe to payment updates for this payment intent
    if connected?(socket) do
      PubSub.subscribe(Shomp.PubSub, "payment_processed:#{payment_intent_id}")
      # Start checking immediately
      send(self(), :check_payment_status)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:check_payment_status, socket) do
    payment_intent_id = socket.assigns.payment_intent_id
    attempts = socket.assigns.attempts

    # Check if we've exceeded max attempts (30 seconds total)
    if attempts >= 15 do
      {:noreply,
       socket
       |> put_flash(:error, "Payment processing is taking longer than expected. Please check your dashboard for updates.")
       |> push_navigate(to: ~p"/dashboard/purchases")}
    else
      # Check database for payment status
      case check_payment_status(payment_intent_id) do
        {:ok, :completed} ->
          # Payment is complete, redirect to success
          {:noreply, push_navigate(socket, to: ~p"/checkout/success?payment_intent=#{payment_intent_id}")}

        {:ok, :failed} ->
          # Payment failed, redirect to error page
          {:noreply,
           socket
           |> put_flash(:error, "Payment failed. Please try again.")
           |> push_navigate(to: ~p"/cart")}

        {:ok, :processing} ->
          # Still processing, check again in 2 seconds
          Process.send_after(self(), :check_payment_status, 2000)
          {:noreply, assign(socket, attempts: attempts + 1)}

        _ ->
          # Payment not found yet, check again in 2 seconds
          Process.send_after(self(), :check_payment_status, 2000)
          {:noreply, assign(socket, attempts: attempts + 1)}
      end
    end
  end

  @impl true
  def handle_info({:payment_processed, payment_intent_id}, socket) do
    # Payment was processed via webhook, redirect immediately
    if payment_intent_id == socket.assigns.payment_intent_id do
      IO.puts("Payment processed via webhook, redirecting to success page")
      {:noreply, push_navigate(socket, to: ~p"/checkout/success?payment_intent=#{payment_intent_id}")}
    else
      {:noreply, socket}
    end
  end

  # Check payment status in database
  defp check_payment_status(payment_intent_id) do
    # First check if we have a universal order for this payment intent
    case UniversalOrders.get_universal_order_by_payment_intent(payment_intent_id) do
      nil ->
        # No universal order found yet, still processing
        {:ok, :processing}

      universal_order ->
        # Check if the universal order is marked as completed
        case universal_order.status do
          "completed" -> {:ok, :completed}
          "failed" -> {:ok, :failed}
          _ -> {:ok, :processing}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 flex items-center justify-center">
      <div class="max-w-md mx-auto text-center">
        <!-- Loading Spinner -->
        <div class="mb-8">
          <div class="loading loading-spinner loading-lg text-primary"></div>
        </div>

        <!-- Status Message -->
        <div class="space-y-4">
          <h1 class="text-2xl font-bold text-base-content">Completing Order...</h1>
          <p class="text-base-content/70">
            Please wait while we process your payment. This may take a few moments.
          </p>

          <!-- Payment Intent ID for debugging -->
          <div class="text-xs text-base-content/50 font-mono">
            Payment ID: <%= @payment_intent_id %>
          </div>
        </div>

        <!-- Progress Steps -->
        <div class="mt-8 space-y-3">
          <div class="flex items-center space-x-3">
            <div class="w-6 h-6 rounded-full bg-success text-success-content flex items-center justify-center text-sm">
              ✓
            </div>
            <span class="text-sm text-base-content/70">Payment submitted</span>
          </div>

          <div class="flex items-center space-x-3">
            <div class="w-6 h-6 rounded-full bg-primary text-primary-content flex items-center justify-center text-sm animate-spin">
              ⏳
            </div>
            <span class="text-sm text-base-content/70">Processing payment</span>
          </div>

          <div class="flex items-center space-x-3">
            <div class="w-6 h-6 rounded-full bg-base-300 text-base-content/50 flex items-center justify-center text-sm">
              ⏳
            </div>
            <span class="text-sm text-base-content/50">Finalizing order</span>
          </div>
        </div>

        <!-- Security Notice -->
        <div class="mt-8 p-4 bg-base-200 rounded-lg">
          <p class="text-sm text-base-content/60">
            🔒 Your payment is secure and encrypted. Do not close this window.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
