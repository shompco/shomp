defmodule ShompWeb.DonationLive.ThankYou do
  use ShompWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, page_title: "Thank You for Your Support")
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-50 to-emerald-100 py-12">
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <!-- Success Icon -->
        <div class="mb-8">
          <div class="mx-auto w-24 h-24 bg-green-100 rounded-full flex items-center justify-center">
            <svg class="w-12 h-12 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
            </svg>
          </div>
        </div>

        <!-- Thank You Message -->
        <h1 class="text-4xl font-bold text-gray-900 mb-6">
          Thank You for Your Support! 🎉
        </h1>
        
        <p class="text-xl text-gray-600 mb-8">
          Your donation helps keep Shomp free and accessible for all creators. We're grateful for your support of our mission to empower artists and creatives.
        </p>

        <!-- What Happens Next -->
        <div class="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 class="text-2xl font-semibold text-gray-900 mb-6">What Happens Next?</h2>
          
          <div class="space-y-4 text-left">
            <div class="flex items-start">
              <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-4 mt-1">
                <span class="text-blue-600 font-semibold text-sm">1</span>
              </div>
              <div>
                <h3 class="font-semibold text-gray-900">Receipt Sent</h3>
                <p class="text-gray-600 text-sm">Check your email for a donation receipt from Stripe</p>
              </div>
            </div>
            
            <div class="flex items-start">
              <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-4 mt-1">
                <span class="text-blue-600 font-semibold text-sm">2</span>
              </div>
              <div>
                <h3 class="font-semibold text-gray-900">Platform Updates</h3>
                <p class="text-gray-600 text-sm">Your support directly funds new features and improvements</p>
              </div>
            </div>
            
            <div class="flex items-start">
              <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-4 mt-1">
                <span class="text-blue-600 font-semibold text-sm">3</span>
              </div>
              <div>
                <h3 class="font-semibold text-gray-900">Stay Connected</h3>
                <p class="text-gray-600 text-sm">Follow our progress and see your impact in action</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="space-y-4">
          <a
            href="/"
            class="inline-block bg-primary hover:bg-primary/90 text-white font-semibold py-4 px-8 rounded-xl text-lg transition-all"
          >
            Return to Shomp
          </a>
          
          <div class="text-sm text-gray-500">
            <a href="/about" class="text-primary hover:underline">Learn more about our mission</a>
            <span class="mx-2">•</span>
            <a href="/requests" class="text-primary hover:underline">See upcoming features</a>
          </div>
        </div>

        <!-- Additional Support -->
        <div class="mt-12 p-6 bg-blue-50 rounded-xl">
          <h3 class="font-semibold text-blue-900 mb-3">Want to Do More?</h3>
          <p class="text-blue-800 text-sm mb-4">
            Share Shomp with other creators, submit feature requests, or consider setting up a monthly recurring donation.
          </p>
          <a
            href="/donations"
            class="inline-block bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg text-sm transition-all"
          >
            Make Another Donation
          </a>
        </div>
      </div>
    </div>
    """
  end
end
