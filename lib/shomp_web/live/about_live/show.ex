defmodule ShompWeb.AboutLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Payments
  alias ShompWeb.Endpoint

  def mount(_params, _session, socket) do
    socket = socket
             |> assign(:page_title, "About Shomp")
    {:ok, socket}
  end

  def handle_event("donate", %{"amount" => amount, "frequency" => frequency}, socket) do
    # Get the current host from the endpoint configuration
    # This will automatically use the correct domain in production
    host = Endpoint.url()

    case Payments.create_donation_session(
      String.to_integer(amount),
      frequency,
      "shomp", # Using "shomp" as the store_slug for platform donations
      "#{host}/payments/success?session_id={CHECKOUT_SESSION_ID}&source=about",
      "#{host}/payments/cancel?source=about"
    ) do
      {:ok, session} ->
        {:noreply, redirect(socket, external: session.url)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create donation session. Please try again.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-base-200 shadow-lg rounded-lg overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-8 border-b border-base-300">
            <h1 class="text-4xl font-bold text-base-content text-center">About Shomp</h1>
            <p class="text-xl text-base-content/70 text-center mt-4">
              Empowering creators to build sustainable livelihoods
            </p>
          </div>

          <!-- Main Content -->
          <div class="px-6 py-8">
            <div class="prose prose-lg max-w-none">
              <div class="text-center mb-8">
                <h2 class="text-2xl font-semibold text-base-content mb-4">Our Mission</h2>
                <p class="text-lg text-base-content/80 leading-relaxed">
                  Empowering U.S. artists and creators by providing a supportive marketplace that enables sustainable livelihoods and fosters creative growth.
                </p>
              </div>



              <div class="grid md:grid-cols-2 gap-8 mt-12">
                <div class="text-center">
                  <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-primary/20 mb-4">
                    <svg class="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                    </svg>
                  </div>
                  <h3 class="text-lg font-semibold text-base-content mb-2">Open Source</h3>
                  <p class="text-base-content/70">
                    Shomp is an open-source project built on Elixir (Erlang), ensuring transparency and community-driven development.
                  </p>
                </div>

                <div class="text-center">
                  <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-primary/20 mb-4">
                    <svg class="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                    </svg>
                  </div>
                  <h3 class="text-lg font-semibold text-base-content mb-2">No Platform Fees</h3>
                  <p class="text-base-content/70">
                    Shomp has no platform fee, ensuring creators keep all of their earnings from sales after Stripe's transaction fee.
                  </p>
                </div>
              </div>

              <div class="mt-12 text-center">
                <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-primary/20 mb-4">
                  <svg class="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-base-content mb-2">Sustained by Donations</h3>
                <p class="text-lg text-base-content/80 leading-relaxed">
                  Shomp is sustained completely by donations from the community who believe in our mission.
                </p>
                <p class="text-base-content/70 mt-4">
                  Every contribution helps us continue building tools that empower creators worldwide.
                </p>
              </div>
            </div>
          </div>

          <!-- Donation Section -->
          <div class="px-6 py-8 bg-base-100 border-t border-base-300">
            <h3 class="text-2xl font-semibold text-base-content text-center mb-6">Support Shomp</h3>
            <p class="text-center text-base-content/70 mb-8">
              Help us continue building a platform that empowers creators
            </p>

            <div class="max-w-2xl mx-auto">
              <div class="grid grid-cols-2 gap-4">
                <button phx-click="donate" phx-value-amount="5" phx-value-frequency="one_time" class="btn btn-outline w-full">
                  Donate $5 (One-Time)
                </button>
                <button phx-click="donate" phx-value-amount="5" phx-value-frequency="monthly" class="btn btn-outline w-full">
                  Donate $5 (Monthly)
                </button>
                <button phx-click="donate" phx-value-amount="10" phx-value-frequency="one_time" class="btn btn-outline w-full">
                  Donate $10 (One-Time)
                </button>
                <button phx-click="donate" phx-value-amount="10" phx-value-frequency="monthly" class="btn btn-outline w-full">
                  Donate $10 (Monthly)
                </button>
                <button phx-click="donate" phx-value-amount="25" phx-value-frequency="one_time" class="btn btn-outline w-full">
                  Donate $25 (One-Time)
                </button>
                <button phx-click="donate" phx-value-amount="25" phx-value-frequency="monthly" class="btn btn-outline w-full">
                  Donate $25 (Monthly)
                </button>
              </div>

              <div class="text-center mt-6">
                <p class="text-sm text-base-content/60">
                  All donations are processed securely through Stripe
                </p>
              </div>
            </div>
          </div>

          <!-- Call to Action -->
          <div class="px-6 py-6 bg-base-200 border-t border-base-300">
            <div class="text-center">
              <a href="/" class="btn btn-primary">
                Back to Home
              </a>
            </div>
          </div>

          <!-- Footer -->
          <div class="px-6 py-8 bg-base-100 border-t border-base-300">
            <div class="text-center">
              <h4 class="text-lg font-semibold text-base-content mb-4">Learn More About Our Mission</h4>
              <p class="text-base-content/70 mb-4">
                Read our latest thoughts on nonprofit marketplaces and the future of creator economies.
              </p>
              <a
                href="https://shompco.wordpress.com/2025/08/20/it-might-be-the-right-time-for-nonprofits/"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center px-4 py-2 bg-primary text-primary-content rounded-lg hover:bg-primary/90 transition-colors"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
                Read Our Blog Post
              </a>
              <p class="text-xs text-base-content/60 mt-3">
                "It Might Be the Right Time for Nonprofits" - August 20, 2025
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
