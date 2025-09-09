defmodule ShompWeb.CheckoutLive.Processing do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(%{"payment_intent_id" => payment_intent_id}, _session, socket) do
    socket = assign(socket, 
      payment_intent_id: payment_intent_id,
      status: "processing"
    )
    
    # Start polling for payment status
    if connected?(socket) do
      Process.send_after(self(), :check_payment_status, 2000)
    end
    
    {:ok, socket}
  end

  @impl true
  def handle_info(:check_payment_status, socket) do
    # Check if payment is complete
    # For now, we'll simulate a delay and then redirect
    # In a real implementation, you'd check the Stripe payment intent status
    
    Process.send_after(self(), :redirect_to_success, 3000)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:redirect_to_success, socket) do
    {:noreply, push_navigate(socket, to: ~p"/checkout/success?payment_intent=#{socket.assigns.payment_intent_id}")}
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
