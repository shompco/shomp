defmodule ShompWeb.MissionLive.Show do
  use ShompWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, page_title: "Our Mission")
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="text-center mb-16">
          <h1 class="text-4xl font-bold text-base-content mb-8">
            Our Mission
          </h1>
          <div class="max-w-4xl mx-auto">
            <blockquote class="text-2xl md:text-3xl font-medium text-base-content/90 leading-relaxed italic">
              <span class="text-6xl text-primary/30 leading-none">"</span>
              Empowering U.S. artists and creators by providing a supportive marketplace that enables sustainable livelihoods and fosters creative growth.
              <span class="text-6xl text-primary/30 leading-none">"</span>
            </blockquote>
          </div>
        </div>

        <!-- Mission Details -->
        <div class="grid md:grid-cols-2 gap-12 mb-16">
          <!-- Core Mission -->
          <div class="bg-base-200 rounded-2xl p-8">
            <h2 class="text-2xl font-bold text-base-content mb-6">Why We Exist</h2>
            <p class="text-base-content/80 leading-relaxed">
              In a world where creative talent often struggles to find sustainable income streams, 
              Shomp bridges the gap between artistic passion and economic viability. We believe 
              that every creator deserves the opportunity to build a thriving business around 
              their craft.
            </p>
          </div>

          <!-- Impact -->
          <div class="bg-primary/10 rounded-2xl p-8">
            <h2 class="text-2xl font-bold text-primary mb-6">Our Impact</h2>
            <p class="text-base-content/80 leading-relaxed">
              By providing tools, community, and a platform designed specifically for creators, 
              we're building an ecosystem where artistic talent can flourish and creators can 
              focus on what they do best: creating.
            </p>
          </div>
        </div>

        <!-- Core Values -->
        <div class="mb-16">
          <h2 class="text-3xl font-bold text-base-content text-center mb-12">Our Core Values</h2>
          <div class="grid md:grid-cols-2 gap-8">
            <!-- Value 1 -->
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-primary/20 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-base-content mb-3">Creator-First Approach</h3>
                <p class="text-base-content/70">
                  Every feature, policy, and decision is made with creators' success in mind. 
                  We prioritize the needs of artists and creators above all else, ensuring 
                  our platform serves as a true partner in their journey.
                </p>
              </div>
            </div>

            <!-- Value 2 -->
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-primary/20 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-base-content mb-3">Community Building</h3>
                <p class="text-base-content/70">
                  We foster a supportive community where creators can connect, collaborate, 
                  and learn from each other. Success is amplified when we lift each other up 
                  and share knowledge and resources.
                </p>
              </div>
            </div>

            <!-- Value 3 -->
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-primary/20 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-base-content mb-3">Transparent & Fair</h3>
                <p class="text-base-content/70">
                  We believe in transparent pricing, clear policies, and fair treatment for all 
                  creators. No hidden fees, no surprise charges, and no preferential treatment 
                  - just honest, straightforward support for creative entrepreneurs.
                </p>
              </div>
            </div>

            <!-- Value 4 -->
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-primary/20 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                  </svg>
                </div>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-base-content mb-3">Continuous Growth</h3>
                <p class="text-base-content/70">
                  We're committed to evolving with our community's needs, constantly improving 
                  our platform and adding features that help creators build sustainable, 
                  long-term businesses around their artistic passions.
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Featured Mission Statement -->
        <div class="text-center mb-16">
          <div class="max-w-4xl mx-auto">
            <blockquote class="text-2xl md:text-3xl font-medium text-base-content/90 leading-relaxed italic">
              <span class="text-6xl text-primary/30 leading-none">"</span>
              Empowering U.S. artists and creators by providing a supportive marketplace that enables sustainable livelihoods and fosters creative growth.
              <span class="text-6xl text-primary/30 leading-none">"</span>
            </blockquote>
          </div>
        </div>

        <!-- Call to Action -->
        <div class="text-center bg-base-200 rounded-2xl p-8">
          <h2 class="text-2xl font-bold text-base-content mb-4">Join Our Mission</h2>
          <p class="text-base-content/70 mb-6 max-w-2xl mx-auto">
            Whether you're a creator looking to build your business or a supporter of the arts, 
            there's a place for you in the Shomp community.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <a href="/stores/new" class="btn btn-primary">
              Start Your Store
            </a>
            <a href="/donations" class="btn btn-outline">
              Support Creators
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
