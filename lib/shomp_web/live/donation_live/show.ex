defmodule ShompWeb.DonationLive.Show do
  use ShompWeb, :live_view
  alias Shomp.Payments

  def mount(_params, _session, socket) do
    socket = assign(socket, 
      page_title: "Support Shomp",
      selected_amount: 10,
      selected_frequency: "one_time",
      custom_amount: "",
      loading: false
    )
    {:ok, socket}
  end

  def handle_event("select-amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, selected_amount: String.to_integer(amount))}
  end

  def handle_event("select-frequency", %{"frequency" => frequency}, socket) do
    {:noreply, assign(socket, selected_frequency: frequency)}
  end

  def handle_event("custom-amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, custom_amount: amount)}
  end

  def handle_event("donate", _params, socket) do
    amount = case socket.assigns.custom_amount do
      "" -> socket.assigns.selected_amount
      custom -> case Integer.parse(custom) do
        {amount, _} -> amount
        :error -> socket.assigns.selected_amount
      end
    end

    frequency = socket.assigns.selected_frequency

    case Payments.create_donation_session(
      amount,
      frequency,
      "shomp", # Platform donations
      url(~p"/donations/thank-you"),
      url(~p"/donations")
    ) do
      {:ok, session} ->
        {:noreply, 
         socket 
         |> assign(loading: false)
         |> redirect(external: session.url)}

      {:error, _reason} ->
        {:noreply, 
         socket 
         |> assign(loading: false)
         |> put_flash(:error, "Failed to create donation session. Please try again.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            Support Shomp's Mission
          </h1>
          <p class="text-xl text-gray-600 max-w-2xl mx-auto">
            Help us keep Shomp free and accessible for all creators. Your donations directly support platform development, server costs, and community features.
          </p>
        </div>

        <!-- Donation Form -->
        <div class="bg-white rounded-2xl shadow-xl p-8 max-w-2xl mx-auto">
          <form phx-submit="donate" class="space-y-8">
            <!-- Amount Selection -->
            <div>
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Choose Your Amount</h3>
              <div class="grid grid-cols-3 gap-4 mb-4">
                <button
                  type="button"
                  phx-click="select-amount"
                  phx-value-amount="5"
                  class={[
                    "py-4 px-6 rounded-xl border-2 font-semibold transition-all",
                    if(@selected_amount == 5, do: "border-primary bg-primary text-white", else: "border-gray-200 hover:border-primary hover:bg-primary/5")
                  ]}
                >
                  $5
                </button>
                <button
                  type="button"
                  phx-click="select-amount"
                  phx-value-amount="10"
                  class={[
                    "py-4 px-6 rounded-xl border-2 font-semibold transition-all",
                    if(@selected_amount == 10, do: "border-primary bg-primary text-white", else: "border-gray-200 hover:border-primary hover:bg-primary/5")
                  ]}
                >
                  $10
                </button>
                <button
                  type="button"
                  phx-click="select-amount"
                  phx-value-amount="25"
                  class={[
                    "py-4 px-6 rounded-xl border-2 font-semibold transition-all",
                    if(@selected_amount == 25, do: "border-primary bg-primary text-white", else: "border-gray-200 hover:border-primary hover:bg-primary/5")
                  ]}
                >
                  $25
                </button>
              </div>
              
              <!-- Custom Amount -->
              <div class="mt-4">
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Or enter a custom amount
                </label>
                <div class="relative">
                  <span class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500">$</span>
                  <input
                    type="number"
                    name="custom_amount"
                    phx-change="custom-amount"
                    value={@custom_amount}
                    min="1"
                    step="1"
                    placeholder="Enter amount"
                    class="w-full pl-8 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary"
                  />
                </div>
              </div>
            </div>

            <!-- Frequency Selection -->
            <div>
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Donation Frequency</h3>
              <div class="grid grid-cols-2 gap-4">
                <button
                  type="button"
                  phx-click="select-frequency"
                  phx-value-frequency="one_time"
                  class={[
                    "py-4 px-6 rounded-xl border-2 font-semibold transition-all text-center",
                    if(@selected_frequency == "one_time", do: "border-primary bg-primary text-white", else: "border-gray-200 hover:border-primary hover:bg-primary/5")
                  ]}
                >
                  <div class="text-lg">One-Time</div>
                  <div class="text-sm opacity-90">Single donation</div>
                </button>
                <button
                  type="button"
                  phx-click="select-frequency"
                  phx-value-frequency="monthly"
                  class={[
                    "py-4 px-6 rounded-xl border-2 font-semibold transition-all text-center",
                    if(@selected_frequency == "monthly", do: "border-primary bg-primary text-white", else: "border-gray-200 hover:border-primary hover:bg-primary/5")
                  ]}
                >
                  <div class="text-lg">Monthly</div>
                  <div class="text-sm opacity-90">Recurring support</div>
                </button>
              </div>
            </div>

            <!-- Impact Information -->
            <div class="bg-blue-50 rounded-xl p-6">
              <h4 class="font-semibold text-blue-900 mb-3">Your Impact</h4>
              <div class="space-y-2 text-sm text-blue-800">
                <div class="flex items-center">
                  <span class="w-2 h-2 bg-blue-500 rounded-full mr-3"></span>
                  <span>Platform development and new features</span>
                </div>
                <div class="flex items-center">
                  <span class="w-2 h-2 bg-blue-500 rounded-full mr-3"></span>
                  <span>Server infrastructure and hosting costs</span>
                </div>
                <div class="flex items-center">
                  <span class="w-2 h-2 bg-blue-500 rounded-full mr-3"></span>
                  <span>Community support and moderation</span>
                </div>
                <div class="flex items-center">
                  <span class="w-2 h-2 bg-blue-500 rounded-full mr-3"></span>
                  <span>Keeping Shomp free for all creators</span>
                </div>
              </div>
            </div>

            <!-- Donate Button -->
            <button
              type="submit"
              disabled={@loading}
              class="w-full bg-primary hover:bg-primary/90 disabled:opacity-50 text-white font-semibold py-4 px-8 rounded-xl text-lg transition-all"
            >
              <%= if @loading do %>
                <span class="flex items-center justify-center">
                  <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Processing...
                </span>
              <% else %>
                <%= if @selected_frequency == "monthly" do %>
                  Donate $<%= @selected_amount %> Monthly
                <% else %>
                  Donate $<%= @selected_amount %> Now
                <% end %>
              <% end %>
            </button>
          </form>
        </div>

        <!-- Additional Info -->
        <div class="mt-12 text-center text-gray-600">
          <p class="mb-4">
            All donations are processed securely through Stripe. You can cancel recurring donations at any time.
          </p>
          <p class="text-sm">
            Questions about donations? <a href="/about" class="text-primary hover:underline">Contact us</a>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
