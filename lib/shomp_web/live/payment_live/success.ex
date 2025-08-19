defmodule ShompWeb.PaymentLive.Success do
  use ShompWeb, :live_view

  alias Shomp.Payments

  def mount(%{"session_id" => session_id} = params, _session, socket) do
    # Get payment details
    payment = Payments.get_payment_by_stripe_id(session_id)
    
    socket = 
      socket
      |> assign(:session_id, session_id)
      |> assign(:payment, payment)
      |> assign(:store_slug, params["store_slug"])
      |> assign(:page_title, "Payment Successful")

    {:ok, socket}
  end

  def handle_event("donate", %{"amount" => amount, "frequency" => frequency}, socket) do
    case Payments.create_donation_session(
      String.to_integer(amount),
      frequency,
      socket.assigns.store_slug,
      "http://localhost:4000/payments/success?session_id={CHECKOUT_SESSION_ID}&store_slug=#{socket.assigns.store_slug}",
      "http://localhost:4000/payments/cancel?store_slug=#{socket.assigns.store_slug}"
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
