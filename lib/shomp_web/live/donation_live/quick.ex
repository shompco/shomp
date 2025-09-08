defmodule ShompWeb.DonationLive.Quick do
  use ShompWeb, :live_view
  alias Shomp.Payments

  def mount(_params, _session, socket) do
    socket = assign(socket, 
      page_title: "Quick Donation",
      loading: false
    )
    {:ok, socket}
  end

  def handle_event("donate", _params, socket) do
    # Create a Stripe checkout session with a custom amount input
    # We'll use a minimal amount and let Stripe handle the custom input
    case create_custom_donation_session() do
      {:ok, session} ->
        {:noreply, redirect(socket, external: session.url)}

      {:error, _reason} ->
        {:noreply, 
         socket 
         |> assign(loading: false)
         |> put_flash(:error, "Failed to create donation session. Please try again.")}
    end
  end

  defp create_custom_donation_session do
    # Create a Stripe session that allows custom amounts
    # We'll use a price with adjustable quantity
    Stripe.Session.create(%{
      payment_method_types: ["card"],
      line_items: [
        %{
          price_data: %{
            currency: "usd",
            product_data: %{
              name: "Donate to Shomp",
              description: "Support Shomp's mission with a custom amount"
            },
            unit_amount: 100  # $1.00 base unit
          },
          quantity: 25,  # Default to $25
          adjustable_quantity: %{
            enabled: true,
            minimum: 1,
            maximum: 1000
          }
        }
      ],
      mode: "payment",
      success_url: "#{ShompWeb.Endpoint.url()}/payments/success?session_id={CHECKOUT_SESSION_ID}&source=donation",
      cancel_url: "#{ShompWeb.Endpoint.url()}/payments/cancel?source=donation",
      metadata: %{
        type: "donation",
        store_slug: "shomp",
        frequency: "one_time"
      }
    })
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 py-12">
      <div class="max-w-md mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-base-content mb-4">
            Quick Donation
          </h1>
          <p class="text-lg text-base-content/70">
            Support Shomp with a custom donation amount
          </p>
        </div>

        <!-- Donation Form -->
        <div class="bg-base-200 rounded-2xl shadow-xl p-8">
          <div class="text-center space-y-6">
            <div class="text-base-content/80">
              <p class="text-lg mb-2">Choose your donation amount</p>
              <p class="text-sm">You'll be able to adjust the amount in Stripe's secure checkout</p>
            </div>

            <!-- Donate Button -->
            <button
              phx-click="donate"
              disabled={@loading}
              class="w-full bg-primary hover:bg-primary/90 disabled:opacity-50 text-primary-content font-semibold py-4 px-8 rounded-xl text-lg transition-all"
            >
              <%= if @loading do %>
                <span class="flex items-center justify-center">
                  <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-primary-content" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Processing...
                </span>
              <% else %>
                💝 Donate Now
              <% end %>
            </button>
          </div>

          <!-- Additional Info -->
          <div class="mt-6 text-center text-sm text-base-content/70">
            <p>
              All donations are processed securely through Stripe.
            </p>
            <p class="mt-2">
              Want more options? <a href="/donations" class="text-primary hover:underline">Visit our full donation page</a>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
