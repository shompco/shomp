defmodule ShompWeb.TosLive.Show do
  use ShompWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, page_title: "Terms of Service")
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 py-12">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-base-200 shadow-lg rounded-lg overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-8 border-b border-base-300">
            <h1 class="text-4xl font-bold text-base-content text-center">Terms of Service</h1>
            <p class="text-xl text-base-content/70 text-center mt-4">
              Effective Date: September 26, 2025
            </p>
          </div>

          <!-- Main Content -->
          <div class="px-6 py-8">
            <div class="prose prose-lg max-w-none">
              <div class="mb-8">
                <p class="text-lg text-base-content/80 leading-relaxed">
                  Welcome to Shomp ("Shomp," "we," "us," or "our"). By creating an account, browsing our site, or using our services, you agree to these Terms of Service ("Terms"). If you do not agree, please do not use Shomp.
                </p>
              </div>

              <div class="space-y-8">
                <!-- Section 1 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">1. Overview of Our Services</h2>
                  <p class="text-base-content/80 leading-relaxed">
                    Shomp is a US-focused marketplace that enables US-based creators ("Sellers") to sell digital and physical products directly to customers ("Buyers"). We provide the platform, payment processing, and certain support tools, but we do not own or ship products on behalf of Sellers. Our mission is to advance economic education and entrepreneurship training for US artists and creators through hands-on business experience.
                  </p>
                </div>

                <!-- Section 2 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">2. Eligibility</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>You must be at least 18 years old (or the age of majority in your jurisdiction) to use Shomp.</li>
                    <li>By registering, you confirm that all information provided is accurate and complete.</li>
                    <li><strong>Sellers must be US-based residents or entities to use Shomp's marketplace services.</strong> This restriction ensures compliance with our 501(c)(3) nonprofit mission to advance economic education and entrepreneurship training for US creators.</li>
                    <li>Sellers must pass Stripe Connect's identity verification (KYC) before receiving payouts.</li>
                  </ul>
                </div>

                <!-- Section 3 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">3. Prohibited Uses & Content</h2>
                  <p class="text-base-content/80 leading-relaxed mb-4">
                    Sellers may not list, sell, or distribute products or services that fall under prohibited or restricted categories, including but not limited to:
                  </p>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Adult or sexually explicit content</li>
                    <li>Gambling, betting, or lottery services</li>
                    <li>Firearms, weapons, or explosives</li>
                    <li>Counterfeit or pirated goods</li>
                    <li>Illegal drugs, controlled substances, or drug paraphernalia</li>
                    <li>Financial services, securities, or cryptocurrencies</li>
                    <li>Hate speech, harassment, or material that infringes on intellectual property rights</li>
                  </ul>
                  <p class="text-base-content/80 leading-relaxed mt-4">
                    We reserve the right to suspend or terminate accounts that violate these rules.
                  </p>
                </div>

                <!-- Section 4 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">4. Payments & Fees</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Payments are processed securely through Stripe.</li>
                    <li>Sellers are responsible for setting their own prices.</li>
                    <li>Buyers authorize Shomp to charge their payment method for all purchases.</li>
                    <li>Shomp may collect a platform fee or optional donation from each transaction, disclosed at checkout.</li>
                    <li>Sellers are responsible for any taxes applicable to their sales.</li>
                  </ul>
                </div>

                <!-- Section 5 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">5. Sellers' Responsibilities</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Sellers must ensure that all product descriptions, pricing, and shipping details are accurate.</li>
                    <li>Sellers are solely responsible for inventory management, order fulfillment, and customer service.</li>
                    <li>Sellers agree not to engage in fraudulent or deceptive practices.</li>
                  </ul>
                </div>

                <!-- Section 6 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">6. Buyers' Responsibilities</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Buyers must provide accurate information for orders, including shipping addresses.</li>
                    <li>Buyers are responsible for reviewing product descriptions before purchase.</li>
                    <li>Refunds, returns, or disputes are subject to the Seller's policies and Stripe's dispute resolution process.</li>
                  </ul>
                </div>

                <!-- Section 7 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">7. Digital Products</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Digital products are delivered through secure download links.</li>
                    <li>Buyers are granted a personal, non-transferable license to use digital products for personal use only, unless otherwise stated.</li>
                    <li>Unauthorized copying, sharing, or redistribution of digital products is prohibited.</li>
                  </ul>
                </div>

                <!-- Section 8 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">8. Donations</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Shomp may accept donations to support platform operations and our 501(c)(3) nonprofit mission.</li>
                    <li>Donations are voluntary, non-refundable, and not tied to specific products or services.</li>
                    <li>Shomp is registering as a 501(c)(3) nonprofit organization focused on advancing economic education and entrepreneurship training for US creators.</li>
                  </ul>
                </div>

                <!-- Section 9 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">9. Intellectual Property</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Sellers retain ownership of their own content and products but grant Shomp a license to display, host, and promote them on the platform.</li>
                    <li>Shomp's name, logo, and platform features are owned by Shomp and may not be used without permission.</li>
                  </ul>
                </div>

                <!-- Section 10 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">10. Limitation of Liability</h2>
                  <ul class="list-disc list-inside space-y-2 text-base-content/80">
                    <li>Shomp is a platform provider only. We do not guarantee the quality, safety, legality, or delivery of any products sold by Sellers.</li>
                    <li>To the fullest extent permitted by law, Shomp is not liable for damages arising from the use of our services.</li>
                  </ul>
                </div>

                <!-- Section 11 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">11. Termination</h2>
                  <p class="text-base-content/80 leading-relaxed">
                    We may suspend or terminate accounts at our discretion if users violate these Terms or applicable laws. Users may terminate their accounts at any time by contacting support.
                  </p>
                </div>

                <!-- Section 12 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">12. Changes to Terms</h2>
                  <p class="text-base-content/80 leading-relaxed">
                    We may update these Terms periodically. Continued use of Shomp after updates constitutes acceptance of the new Terms.
                  </p>
                </div>

                <!-- Section 13 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">13. Governing Law</h2>
                  <p class="text-base-content/80 leading-relaxed">
                    These Terms are governed by the laws of the State of Ohio, without regard to its conflict of law principles.
                  </p>
                </div>

                <!-- Section 14 -->
                <div class="bg-base-100 p-6 rounded-lg border border-base-300">
                  <h2 class="text-2xl font-semibold text-primary mb-4">14. Contact Us</h2>
                  <p class="text-base-content/80 leading-relaxed mb-4">
                    For questions or support, please contact:
                  </p>
                  <div class="bg-base-200 p-4 rounded-lg">
                    <p class="text-base-content/80">
                      <strong>Shomp Support</strong><br>
                      Email: <a href="mailto:support@shomp.co" class="text-primary hover:text-primary/80">support@shomp.co</a><br>
                      Website: <a href="https://shomp.co" class="text-primary hover:text-primary/80">shomp.co</a>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
