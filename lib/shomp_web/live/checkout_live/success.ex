defmodule ShompWeb.CheckoutLive.Success do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.UniversalOrders
  alias Shomp.PaymentSplits

  @impl true
  def mount(%{"payment_intent" => payment_intent_id}, _session, socket) do
    # Get payment intent ID from URL params
    load_order_data(socket, payment_intent_id)
  end

  def mount(_params, _session, socket) do
    # Fallback if no payment_intent provided
    {:ok, 
     socket
     |> put_flash(:error, "No payment information found")
     |> push_navigate(to: ~p"/")}
  end

  defp load_order_data(socket, payment_intent_id) do
    if payment_intent_id do
      # Look up the universal order
      case UniversalOrders.get_universal_order_by_payment_intent(payment_intent_id) do
        nil ->
          {:ok, 
           socket
           |> put_flash(:error, "Order not found")
           |> push_navigate(to: ~p"/")}
        
        universal_order ->
          # Get payment splits for this order
          payment_splits = PaymentSplits.list_payment_splits_by_universal_order(universal_order.id)
          
          {:ok, assign(socket, 
            universal_order: universal_order,
            payment_splits: payment_splits
          )}
      end
    else
      {:ok, 
       socket
       |> put_flash(:error, "No payment information found")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <!-- Success Header -->
      <div class="bg-success/10 border-b border-success/20">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-success/20 mb-4">
              <svg class="h-8 w-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h1 class="text-3xl font-bold text-success mb-2">Payment Successful!</h1>
            <p class="text-lg text-base-content/80">
              Thank you for your purchase. Your order has been processed.
            </p>
          </div>
        </div>
      </div>

      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Order Details -->
          <div class="space-y-6">
            <div class="bg-base-200 rounded-2xl p-6">
              <h2 class="text-xl font-semibold text-base-content mb-4">Order Details</h2>
              
              <div class="space-y-3">
                <div class="flex justify-between">
                  <span class="text-base-content/70">Order ID</span>
                  <span class="font-mono text-sm"><%= @universal_order.universal_order_id %></span>
                </div>
                
                <div class="flex justify-between">
                  <span class="text-base-content/70">Total Amount</span>
                  <span class="font-semibold">$<%= @universal_order.total_amount %></span>
                </div>
                
                <%= if Decimal.gt?(@universal_order.platform_fee_amount, 0) do %>
                  <div class="flex justify-between">
                    <span class="text-base-content/70">Donation to Shomp</span>
                    <span>$<%= @universal_order.platform_fee_amount %></span>
                  </div>
                <% end %>
                
                <div class="flex justify-between">
                  <span class="text-base-content/70">Status</span>
                  <span class="badge badge-success">Paid</span>
                </div>
              </div>
            </div>

            <!-- Next Steps -->
            <div class="bg-primary/5 rounded-2xl p-6 border border-primary/20">
              <h3 class="text-lg font-semibold text-primary mb-3">What's Next?</h3>
              <ul class="space-y-2 text-sm text-base-content/80">
                <li class="flex items-start space-x-2">
                  <span class="text-primary mt-1">•</span>
                  <span>You'll receive a confirmation email shortly</span>
                </li>
                <li class="flex items-start space-x-2">
                  <span class="text-primary mt-1">•</span>
                  <span>For digital products, download links will be sent to your email</span>
                </li>
                <li class="flex items-start space-x-2">
                  <span class="text-primary mt-1">•</span>
                  <span>You can track your order in your account dashboard</span>
                </li>
              </ul>
            </div>
          </div>

          <!-- Payment Breakdown -->
          <div class="space-y-6">
            <div class="bg-base-200 rounded-2xl p-6">
              <h2 class="text-xl font-semibold text-base-content mb-4">Payment Breakdown</h2>
              
              <div class="space-y-4">
                <%= for payment_split <- @payment_splits do %>
                  <div class="border border-base-300 rounded-lg p-4">
                    <div class="flex justify-between items-start mb-2">
                      <span class="font-medium text-base-content">Store Payment</span>
                      <span class="font-semibold">$<%= payment_split.store_amount %></span>
                    </div>
                    
                    <%= if Decimal.gt?(payment_split.platform_fee_amount, 0) do %>
                      <div class="flex justify-between items-center text-sm text-base-content/70">
                        <span>Donation to Shomp (5%)</span>
                        <span>$<%= payment_split.platform_fee_amount %></span>
                      </div>
                    <% end %>
                    
                    <div class="flex justify-between items-center text-sm text-base-content/70 mt-2 pt-2 border-t border-base-300">
                      <span>Total to Store</span>
                      <span>$<%= payment_split.total_amount %></span>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Actions -->
            <div class="space-y-3">
              <.link
                navigate={~p"/dashboard/orders"}
                class="w-full bg-primary hover:bg-primary-focus text-primary-content font-semibold py-3 px-6 rounded-lg text-center block transition-colors"
              >
                View All Orders
              </.link>
              
              <.link
                navigate={~p"/stores"}
                class="w-full bg-base-300 hover:bg-base-400 text-base-content font-semibold py-3 px-6 rounded-lg text-center block transition-colors"
              >
                Continue Shopping
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
