defmodule ShompWeb.CheckoutLive.SingleProduct do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Products
  alias Shomp.ShippingCalculator

  @impl true
  def mount(%{"product_id" => product_id} = params, _session, socket) do
    product = Products.get_product_with_store!(product_id)

    # Get donation preference from URL params or default to true
    donate = case params["donate"] do
      "true" -> true
      "false" -> false
      _ -> true
    end

    # Get referrer information
    from = params["from"] || "unknown"
    store_slug = params["store"]

    # Calculate amounts
    platform_fee_rate = Decimal.new("0.05")
    platform_fee_amount = if donate do
      Decimal.mult(product.price, platform_fee_rate)
    else
      Decimal.new("0")
    end
    total_amount = if donate do
      Decimal.add(product.price, platform_fee_amount)
    else
      product.price
    end

    # Generate universal order ID
    universal_order_id = generate_universal_order_id()

    # Initialize shipping form for physical products
    shipping_form = if product.type == "physical" do
      to_form(%{
        "name" => "",
        "street1" => "",
        "city" => "",
        "state" => "",
        "zip" => "",
        "country" => "US"
      })
    else
      nil
    end

    socket = assign(socket,
      product: product,
      platform_fee_rate: platform_fee_rate,
      platform_fee_amount: platform_fee_amount,
      total_amount: total_amount,
      universal_order_id: universal_order_id,
      donate: donate,
      payment_intent_id: nil,
      payment_status: "pending",
      error_message: nil,
      from: from,
      store_slug: store_slug,
      shipping_form: shipping_form,
      shipping_options: [],
      selected_shipping_option: nil,
      shipping_cost: 0.0,
      shipping_loading: false
    )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <!-- Header -->
      <div class="bg-base-200 border-b border-base-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="flex items-center justify-between">
            <h1 class="text-2xl font-bold text-base-content">Checkout</h1>
            <button
              onclick="history.back()"
              class="text-primary hover:text-primary-focus transition-colors"
            >
              ← Back
            </button>
          </div>
        </div>
      </div>

      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Left Column: Product Summary -->
          <div class="space-y-6">
            <div class="bg-base-200 rounded-2xl p-6">
              <h2 class="text-xl font-semibold text-base-content mb-4">Order Summary</h2>

              <!-- Product Info -->
              <div class="flex space-x-4 mb-4">
                <div class="w-16 h-16 bg-base-300 rounded-lg flex items-center justify-center">
                  <%= cond do %>
                    <% @product.image_thumb && @product.image_thumb != "" -> %>
                      <img src={@product.image_thumb} alt={@product.title} class="w-full h-full object-cover rounded-lg" />
                    <% @product.image_medium && @product.image_medium != "" -> %>
                      <img src={@product.image_medium} alt={@product.title} class="w-full h-full object-cover rounded-lg" />
                    <% @product.image_original && @product.image_original != "" -> %>
                      <img src={@product.image_original} alt={@product.title} class="w-full h-full object-cover rounded-lg" />
                    <% true -> %>
                      <div class="text-base-content/40 text-xs">No Image</div>
                  <% end %>
                </div>
                <div class="flex-1">
                  <h3 class="font-medium text-base-content"><%= @product.title %></h3>
                  <p class="text-sm text-base-content/70"><%= @product.store.name %></p>
                  <p class="text-sm text-base-content/70">Quantity: 1</p>
                </div>
                <div class="text-right">
                  <p class="font-medium text-base-content">$<%= @product.price %></p>
                </div>
              </div>

              <!-- Platform Donation -->
              <div class="border-t border-base-300 pt-4">
                <div class={"donation-row flex justify-between items-center mb-2 #{if @donate, do: "", else: "hidden"}"}>
                  <span class="text-base-content/70">Donation to Shomp (5%)</span>
                  <span class="donation-amount text-base-content/70">$<%= format_amount(@platform_fee_amount) %></span>
                </div>

                <!-- Shipping Cost (only for physical products) -->
                <%= if @product.type == "physical" do %>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-base-content/70">Shipping</span>
                    <span class="text-base-content/70">
                      <%= if @shipping_cost > 0 do %>
                        $<%= :erlang.float_to_binary(@shipping_cost, decimals: 2) %>
                      <% else %>
                        TBD
                      <% end %>
                    </span>
                  </div>
                <% end %>

                <div class="total-row flex justify-between items-center text-lg font-semibold">
                  <span>Total</span>
                  <span class="total-amount">
                    <%= if @product.type == "physical" && @shipping_cost > 0 do %>
                      $<%= :erlang.float_to_binary(Decimal.to_float(@product.price) + @shipping_cost + (if @donate, do: Decimal.to_float(@platform_fee_amount), else: 0), decimals: 2) %>
                    <% else %>
                      $<%= if @donate, do: format_amount(@total_amount), else: format_amount(@product.price) %><%= if @product.type == "physical", do: " + shipping" %>
                    <% end %>
                  </span>
                </div>
              </div>
            </div>

            <!-- Donation Toggle -->
            <div class="bg-base-200 rounded-2xl p-6">
              <div class="flex items-center space-x-3">
                <input
                  type="checkbox"
                  id="donate_checkbox"
                  checked={@donate}
                  class="checkbox checkbox-primary"
                />
                <label for="donate_checkbox" class="text-base-content/80 cursor-pointer">
                  <span class="font-medium">Support Shomp</span>
                  <p class="text-sm text-base-content/60">
                    Your donation helps cover infrastructure costs and enables us to provide a supportive marketplace for creators.
                  </p>
                </label>
              </div>
            </div>

          </div>

          <!-- Right Column: Payment Form -->
          <div class="space-y-6">
            <div class="bg-base-200 rounded-2xl p-6">
              <h2 class="text-xl font-semibold text-base-content mb-4">
                <%= if @product.type == "physical", do: "Shipping & Payment Details", else: "Payment Details" %>
              </h2>

              <!-- Customer Information Form -->
              <div class="space-y-6 mb-6">
                <!-- Name and Email Section -->
                <div>
                  <h3 class="text-lg font-medium text-base-content mb-4">Contact Information</h3>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium text-base-content mb-2">
                        Full Name *
                      </label>
                      <input
                        type="text"
                        id="customer-name"
                        required
                        class="input input-bordered w-full"
                        placeholder="John Doe"
                        value={if @current_scope && @current_scope.user, do: @current_scope.user.name || "", else: ""}
                      />
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-base-content mb-2">
                        Email Address *
                      </label>
                      <input
                        type="email"
                        id="customer-email"
                        required
                        class="input input-bordered w-full"
                        placeholder="your@email.com"
                        value={if @current_scope && @current_scope.user, do: @current_scope.user.email || "", else: ""}
                      />
                    </div>
                  </div>
                  <p class="text-sm text-base-content/60 mt-2">
                    We'll send your receipt and <%= if @product.type == "physical", do: "shipping updates", else: "download link" %> to this email.
                  </p>
                </div>

                <!-- Physical Product Shipping Address -->
                <%= if @product.type == "physical" do %>
                  <div>
                    <h3 class="text-lg font-medium text-base-content mb-4">Shipping Address</h3>

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          Address Line 1 *
                        </label>
                        <input
                          type="text"
                          id="address-line1"
                          required
                          class="input input-bordered w-full"
                          placeholder="123 Main Street"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          Address Line 2
                        </label>
                        <input
                          type="text"
                          id="address-line2"
                          class="input input-bordered w-full"
                          placeholder="Apt 4B"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          City *
                        </label>
                        <input
                          type="text"
                          id="city"
                          required
                          class="input input-bordered w-full"
                          placeholder="New York"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          State/Province *
                        </label>
                        <input
                          type="text"
                          id="state"
                          required
                          class="input input-bordered w-full"
                          placeholder="NY"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          Postal Code *
                        </label>
                        <input
                          type="text"
                          id="postal-code"
                          required
                          class="input input-bordered w-full"
                          placeholder="10001"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          Country *
                        </label>
                        <select id="country" required class="select select-bordered w-full">
                          <option value="">Select Country</option>
                          <option value="US" selected>United States</option>
                          <option value="CA">Canada</option>
                          <option value="GB">United Kingdom</option>
                          <option value="AU">Australia</option>
                          <option value="DE">Germany</option>
                          <option value="FR">France</option>
                          <option value="IT">Italy</option>
                          <option value="ES">Spain</option>
                          <option value="NL">Netherlands</option>
                          <option value="SE">Sweden</option>
                          <option value="NO">Norway</option>
                          <option value="DK">Denmark</option>
                          <option value="FI">Finland</option>
                          <option value="CH">Switzerland</option>
                          <option value="AT">Austria</option>
                          <option value="BE">Belgium</option>
                          <option value="IE">Ireland</option>
                          <option value="PT">Portugal</option>
                          <option value="GR">Greece</option>
                          <option value="PL">Poland</option>
                          <option value="CZ">Czech Republic</option>
                          <option value="HU">Hungary</option>
                          <option value="SK">Slovakia</option>
                          <option value="SI">Slovenia</option>
                          <option value="HR">Croatia</option>
                          <option value="RO">Romania</option>
                          <option value="BG">Bulgaria</option>
                          <option value="LT">Lithuania</option>
                          <option value="LV">Latvia</option>
                          <option value="EE">Estonia</option>
                          <option value="LU">Luxembourg</option>
                          <option value="MT">Malta</option>
                          <option value="CY">Cyprus</option>
                        </select>
                      </div>
                    </div>

                    <!-- Shipping Calculator Section -->
                    <%= if @product.type == "physical" do %>
                      <div class="mt-6">
                        <h3 class="text-lg font-medium text-base-content mb-4">Shipping Method</h3>

                        <!-- Calculate Shipping Button -->
                        <div class="mb-4">
                          <button
                            type="button"
                            id="calculate-shipping-btn"
                            class="btn btn-primary"
                            onclick="calculateShippingWithAddress()"
                          >
                            Calculate Shipping Rates
                          </button>
                        </div>

                        <!-- Shipping Options Container -->
                        <div id="shipping-options-container">
                          <div class="text-center py-4">
                            <p class="text-sm text-base-content/60">Click "Calculate Shipping Rates" to see available options</p>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>


                <!-- Card Information Section -->
                <div>
                  <h3 class="text-lg font-medium text-base-content mb-4">Payment Information</h3>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      Card Information *
                    </label>
                    <div id="card-element" class="p-3 border border-base-300 rounded-lg bg-base-100 min-h-[50px]">
                      <!-- Stripe Elements will be mounted here -->
                    </div>
                    <div id="card-errors" class="text-error text-sm mt-2" role="alert"></div>
                  </div>
                </div>
              </div>

              <!-- Hidden inputs for shipping data -->
              <div id="shipping-data" style="display: none;"></div>

              <!-- Payment Button -->
              <div class="space-y-4">

                <!-- Payment Button -->
                <button
                  id="submit-payment"
                  type="button"
                  disabled={@payment_status == "processing"}
                  class="w-full bg-primary hover:bg-primary-focus text-primary-content font-semibold py-3 px-6 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  <%= if @payment_status == "processing" do %>
                    Processing Payment...
                  <% else %>
                    <span id="checkout-button-text">
                      <%= if @product.type == "physical", do: "Complete Order", else: "Complete Purchase" %> - $<%= if @donate, do: format_amount(@total_amount), else: format_amount(@product.price) %>
                    </span>
                  <% end %>
                </button>
              </div>

              <!-- Error Message -->
              <%= if @error_message do %>
                <div class="mt-4 p-4 bg-error/10 border border-error/20 rounded-lg">
                  <p class="text-error text-sm"><%= @error_message %></p>
                </div>
              <% end %>

              <!-- Success Message -->
              <%= if @payment_status == "succeeded" do %>
                <div class="mt-4 p-4 bg-success/10 border border-success/20 rounded-lg">
                  <p class="text-success text-sm">Payment successful! Redirecting...</p>
                </div>
              <% end %>
            </div>

            <!-- Security Notice -->
            <div class="text-center text-sm text-base-content/60">
              <p>🔒 Your payment information is secure and encrypted</p>
              <p>Powered by Stripe</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Stripe Elements Script -->
      <script src="https://js.stripe.com/v3/"></script>

      <!-- Shipping Options Data -->
      <script>
        window.shippingOptions = <%= if @shipping_options, do: Jason.encode!(@shipping_options), else: "[]" %>;
      </script>

      <script>
        console.log('=== STRIPE CHECKOUT DEBUG ===');
        console.log('Script loaded at:', new Date().toISOString());

        // Global variables for Stripe
        let stripe, cardElement;

        // Simple test function
        function testStripe() {
          console.log('Testing Stripe availability...');
          console.log('Stripe available:', typeof Stripe !== 'undefined');
          console.log('Document ready:', document.readyState);
          console.log('Card container exists:', !!document.getElementById('card-element'));

          if (typeof Stripe !== 'undefined') {
            console.log('Stripe object:', Stripe);
            const publishableKey = '<%= Application.get_env(:shomp, :stripe_publishable_key) %>';
            console.log('Publishable key:', publishableKey);

            if (publishableKey && publishableKey !== '') {
              try {
                stripe = Stripe(publishableKey);
                console.log('Stripe instance created successfully');

                const elements = stripe.elements();
                console.log('Elements created successfully');

                cardElement = elements.create('card');
                console.log('Card element created successfully');

                const container = document.getElementById('card-element');
                if (container) {
                  cardElement.mount('#card-element');
                  console.log('Card element mounted successfully!');

                  // Set up payment button
                  setupPaymentButton();

                  // Set up shipping price updates (with error handling)
                  try {
                    setupShippingPriceUpdates();
                  } catch (error) {
                    console.error('Error setting up shipping price updates:', error);
                  }

                  // Test if element is visible
                  setTimeout(() => {
                    const mountedElement = document.querySelector('#card-element .StripeElement');
                    console.log('Mounted element found:', !!mountedElement);
                    if (mountedElement) {
                      console.log('Element dimensions:', mountedElement.getBoundingClientRect());
                    }
                  }, 1000);

                } else {
                  console.error('Card container not found!');
                }
              } catch (error) {
                console.error('Error creating Stripe elements:', error);
              }
            } else {
              console.error('No publishable key found!');
            }
          } else {
            console.error('Stripe library not loaded!');
          }
        }

        // Set up payment button event listener
        function setupPaymentButton() {
          const submitButton = document.getElementById('submit-payment');
          if (submitButton) {
            submitButton.addEventListener('click', handlePayment);
            console.log('Payment button event listener attached');
          } else {
            console.error('Payment button not found');
          }
        }

        // Set up shipping price updates
        function setupShippingPriceUpdates() {
          console.log('Setting up shipping price updates...');

          // Listen for shipping option changes
          document.addEventListener('change', function(event) {
            console.log('Change event detected:', event.target.name, event.target.value);

            if (event.target.name === 'shipping_option') {
              console.log('Shipping option selected:', event.target.value);

              console.log('Shipping options available:', window.shippingOptions);

              if (window.shippingOptions && window.shippingOptions.length > 0) {
                console.log('Shipping options:', window.shippingOptions);

                try {
                  const shippingOptions = window.shippingOptions;
                  console.log('Parsed shipping options:', shippingOptions);

                  const selectedOption = shippingOptions.find(option => option.id === event.target.value);
                  console.log('Selected option:', selectedOption);

                  if (selectedOption) {
                    console.log('Updating total price with shipping cost:', selectedOption.cost);
                    updateTotalPrice(parseFloat(selectedOption.cost));
                  } else {
                    console.log('Selected option not found in shipping options');
                  }
                } catch (error) {
                  console.error('Error parsing shipping options:', error);
                }
              } else {
                console.log('Shipping data input not found or empty');
              }
            }
          });

          console.log('Shipping price updates setup complete');
        }

        // Function to update total price
        function updateTotalPrice(shippingCost = <%= @shipping_cost %>) {
          console.log('updateTotalPrice called with shipping cost:', shippingCost);

          const productPrice = <%= Decimal.to_float(@product.price) %>;
          const donate = <%= @donate %>;

          console.log('Product price:', productPrice);
          console.log('Donate enabled:', donate);
          console.log('Shipping cost:', shippingCost);

          // Calculate total based on donation setting
          let totalAmount;
          if (donate) {
            // (item cost + shipping cost) * 1.05
            totalAmount = (productPrice + shippingCost) * 1.05;
          } else {
            // (item cost + shipping cost)
            totalAmount = productPrice + shippingCost;
          }

          console.log('Calculated total amount:', totalAmount);

          // Update the total display element
          const totalElement = document.querySelector('.total-amount');
          console.log('Total element found:', !!totalElement);

          if (totalElement) {
            const newText = '$' + totalAmount.toFixed(2);
            console.log('Updating total element text to:', newText);
            totalElement.textContent = newText;
          }

          // Update the checkout button text
          const checkoutButtonText = document.getElementById('checkout-button-text');
          console.log('Checkout button text element found:', !!checkoutButtonText);

          if (checkoutButtonText) {
            const buttonText = '<%= if @product.type == "physical", do: "Complete Order", else: "Complete Purchase" %> - $' + totalAmount.toFixed(2);
            console.log('Updating checkout button text to:', buttonText);
            checkoutButtonText.textContent = buttonText;
          }
        }

        // Collect form data
        function collectFormData() {
          // Calculate current total with shipping
          const productPrice = <%= Decimal.to_float(@product.price) %>;
          const donate = <%= @donate %>;
          const shippingCost = <%= @shipping_cost %>;

          let currentTotal;
          if (donate) {
            currentTotal = (productPrice + shippingCost) * 1.05;
          } else {
            currentTotal = productPrice + shippingCost;
          }

          const formData = {
            product_id: '<%= @product.id %>',
            universal_order_id: '<%= @universal_order_id %>',
            donate: donate,
            customer_email: document.getElementById('customer-email').value,
            customer_name: document.getElementById('customer-name').value,
            total_amount: currentTotal
          };

          // Add shipping address and method for physical products
          <%= if @product.type == "physical" do %>
          formData.shipping_address = {
            line1: document.getElementById('address-line1').value,
            line2: document.getElementById('address-line2').value,
            city: document.getElementById('city').value,
            state: document.getElementById('state').value,
            postal_code: document.getElementById('postal-code').value,
            country: document.getElementById('country').value
          };

          // Add selected shipping method
          const selectedShippingOption = document.querySelector('input[name="shipping_option"]:checked');
          if (selectedShippingOption) {
            const optionId = selectedShippingOption.value;
            // Get shipping option data from global variable
            if (window.shippingOptions) {
              const shippingOptions = window.shippingOptions;
              const selectedOption = shippingOptions.find(option => option.id === optionId);
              if (selectedOption) {
                formData.shipping_method = {
                  id: selectedOption.id,
                  name: selectedOption.name,
                  carrier: selectedOption.carrier,
                  cost: selectedOption.cost,
                  estimated_days: selectedOption.estimated_days,
                  service_token: selectedOption.service_token
                };
              }
            }
          }
          <% end %>

          return formData;
        }

        // Validate form data
        function validateFormData(formData) {
          const errors = [];

          // Email validation
          if (!formData.customer_email) {
            errors.push('Email address is required');
          } else if (!formData.customer_email.includes('@') || !formData.customer_email.includes('.')) {
            errors.push('Please enter a valid email address (e.g., user@example.com)');
          }

          // Name validation
          if (!formData.customer_name) {
            errors.push('Full name is required');
          } else if (formData.customer_name.trim().length < 2) {
            errors.push('Please enter your full name (at least 2 characters)');
          }

          <%= if @product.type == "physical" do %>
          // Shipping address validation (street address optional)

          if (!formData.shipping_address.city) {
            errors.push('City is required');
          } else if (formData.shipping_address.city.trim().length < 2) {
            errors.push('Please enter a valid city name');
          }

          if (!formData.shipping_address.state) {
            errors.push('State/Province is required');
          } else if (formData.shipping_address.state.trim().length < 2) {
            errors.push('Please enter a valid state or province');
          }

          if (!formData.shipping_address.postal_code) {
            errors.push('Postal code is required');
          } else if (formData.shipping_address.postal_code.trim().length < 3) {
            errors.push('Please enter a valid postal code');
          }

          if (!formData.shipping_address.country) {
            errors.push('Please select a country');
          }
          <% end %>

          return errors;
        }

        // Handle payment submission
        async function handlePayment(event) {
          event.preventDefault();

          console.log('=== PAYMENT SUBMISSION STARTED ===');
          console.log('Event:', event);
          console.log('Timestamp:', new Date().toISOString());

          const submitButton = document.getElementById('submit-payment');
          if (!submitButton || !stripe || !cardElement) {
            console.error('Payment system not ready');
            console.error('Submit button exists:', !!submitButton);
            console.error('Stripe exists:', !!stripe);
            console.error('Card element exists:', !!cardElement);
            return;
          }

          // Collect and validate form data
          console.log('Collecting form data...');
          const formData = collectFormData();
          console.log('Form data collected:', formData);

          console.log('Validating form data...');
          const validationErrors = validateFormData(formData);
          console.log('Validation errors:', validationErrors);

          if (validationErrors.length > 0) {
            console.error('Validation failed:', validationErrors);
            const displayError = document.getElementById('card-errors');
            if (displayError) {
              displayError.textContent = 'Please fix the following errors: ' + validationErrors.join(', ');
              displayError.style.color = '#ef4444'; // Red color for errors
            }
            return;
          }

          // Clear any previous errors
          const displayError = document.getElementById('card-errors');
          if (displayError) {
            displayError.textContent = '';
          }

          // Disable button
          submitButton.disabled = true;
          submitButton.textContent = 'Processing...';

          try {
            console.log('Creating payment intent...');
            console.log('Request URL:', '/api/create-payment-intent');
            console.log('Request body:', JSON.stringify(formData, null, 2));

            // Create payment intent
            const response = await fetch('/api/create-payment-intent', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
              },
              body: JSON.stringify(formData)
            });

            console.log('Response received:', response);
            console.log('Response status:', response.status);
            console.log('Response headers:', Object.fromEntries(response.headers.entries()));

            const data = await response.json();
            console.log('Response data:', data);

            if (data.error) {
              console.error('Server error:', data.error);
              throw new Error(data.error);
            }

            console.log('Payment intent created successfully');
            console.log('Client secret:', data.client_secret);
            console.log('Payment intent ID:', data.payment_intent_id);

            // Confirm payment
            console.log('Confirming payment with Stripe...');
            console.log('Billing details:', {
              name: formData.customer_name,
              email: formData.customer_email,
              <%= if @product.type == "physical" do %>
              address: formData.shipping_address
              <% end %>
            });

            const result = await stripe.confirmCardPayment(data.client_secret, {
              payment_method: {
                card: cardElement,
                billing_details: {
                  name: formData.customer_name,
                  email: formData.customer_email,
                  <%= if @product.type == "physical" do %>
                  address: {
                    line1: formData.shipping_address.line1,
                    line2: formData.shipping_address.line2,
                    city: formData.shipping_address.city,
                    state: formData.shipping_address.state,
                    postal_code: formData.shipping_address.postal_code,
                    country: formData.shipping_address.country
                  }
                  <% end %>
                }
              }
            });

            console.log('Stripe confirmation result:', result);

            if (result.error) {
              console.error('Stripe error:', result.error);
              console.error('Error code:', result.error.code);
              console.error('Error type:', result.error.type);
              console.error('Error message:', result.error.message);
              console.error('Error decline_code:', result.error.decline_code);

              const displayError = document.getElementById('card-errors');
              if (displayError) {
                displayError.textContent = result.error.message;
              }

              // Re-enable button
              submitButton.disabled = false;
              updateButtonText();
            } else {
              console.log('Payment succeeded!');
              console.log('Payment intent:', result.paymentIntent);
              // Payment succeeded - redirect to processing page
              window.location.href = '/checkout/processing/' + result.paymentIntent.id;
            }

          } catch (error) {
            console.error('=== PAYMENT ERROR ===');
            console.error('Error name:', error.name);
            console.error('Error message:', error.message);
            console.error('Error stack:', error.stack);
            console.error('Full error object:', error);

            const displayError = document.getElementById('card-errors');
            if (displayError) {
              displayError.textContent = error.message;
            }

            // Re-enable button
            submitButton.disabled = false;
            updateButtonText();
          }
        }

        // Function to update button text based on donation state
        function updateButtonText() {
          const donateCheckbox = document.getElementById('donate_checkbox');
          const submitButton = document.getElementById('submit-payment');
          const productPrice = <%= Decimal.to_float(@product.price) %>;
          const donationAmount = donateCheckbox.checked ? productPrice * 0.05 : 0;
          const totalAmount = productPrice + donationAmount;
          const buttonText = '<%= if @product.type == "physical", do: "Complete Order", else: "Complete Purchase" %> - $' + totalAmount.toFixed(2);
          submitButton.textContent = buttonText;
        }

        // Function to handle donation toggle
        function handleDonationToggle() {
          const donateCheckbox = document.getElementById('donate_checkbox');
          const donationRow = document.querySelector('.donation-row');
          const totalRow = document.querySelector('.total-row');
          const productPrice = <%= Decimal.to_float(@product.price) %>;
          const donationAmount = productPrice * 0.05;

          if (donateCheckbox && donateCheckbox.checked) {
            // Show donation row and update amounts
            if (donationRow) {
              donationRow.classList.remove('hidden');
              const donationAmountEl = donationRow.querySelector('.donation-amount');
              if (donationAmountEl) {
                donationAmountEl.textContent = '$' + donationAmount.toFixed(2);
              }
            }
            // Update total
            if (totalRow) {
              const totalAmountEl = totalRow.querySelector('.total-amount');
              if (totalAmountEl) {
                totalAmountEl.textContent = '$' + (productPrice + donationAmount).toFixed(2);
              }
            }
          } else {
            // Hide donation row and reset amounts
            if (donationRow) {
              donationRow.classList.add('hidden');
            }
            // Update total
            if (totalRow) {
              const totalAmountEl = totalRow.querySelector('.total-amount');
              if (totalAmountEl) {
                totalAmountEl.textContent = '$' + productPrice.toFixed(2);
              }
            }
          }

          updateButtonText();
        }

        // Add event listener to donation checkbox
        function setupDonationToggle() {
          const donateCheckbox = document.getElementById('donate_checkbox');
          if (donateCheckbox) {
            donateCheckbox.addEventListener('change', handleDonationToggle);
          } else {
            setTimeout(setupDonationToggle, 100);
          }
        }


        // Initialize when ready
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', function() {
            testStripe();
            setupDonationToggle();
          });
        } else {
          testStripe();
          setupDonationToggle();
        }

        // Re-initialize Stripe after LiveView updates
        document.addEventListener('phx:updated', function() {
          console.log('LiveView updated, checking Stripe element...');
          const existingElement = document.querySelector('#card-element .StripeElement');
          if (!existingElement) {
            console.log('Stripe element missing after update, re-initializing...');
            setTimeout(testStripe, 100);
          }
        });

        // LiveView hook for calculate shipping button
        const CalculateShipping = {
          mounted() {
            console.log('CalculateShipping hook mounted');
          },

          handleEvent(event, payload) {
            console.log('CalculateShipping hook received event:', event);

            if (event === 'calculate_shipping') {
              // Collect address data from the form
              const addressData = {
                name: document.getElementById('customer-name')?.value || 'Customer',
                street1: document.getElementById('address-line1')?.value || '',
                city: document.getElementById('city')?.value || '',
                state: document.getElementById('state')?.value || '',
                zip: document.getElementById('postal-code')?.value || '',
                country: document.getElementById('country')?.value || 'US'
              };

              console.log('Collected address data:', addressData);

              // Validate required fields
              if (!addressData.street1 || !addressData.city || !addressData.state || !addressData.zip) {
                alert('Please fill in all required address fields before calculating shipping.');
                return;
              }

              // Show loading state
              const container = document.getElementById('shipping-options-container');
              if (container) {
                container.innerHTML = `
                  <div class="flex items-center justify-center py-4">
                    <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary"></div>
                    <span class="ml-2 text-sm text-base-content/70">Calculating shipping rates...</span>
                  </div>
                `;
              }

              // Make API call to calculate shipping
              fetch('/api/calculate-shipping', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                },
                body: JSON.stringify({
                  product_id: '<%= @product.id %>',
                  shipping_address: addressData
                })
              })
              .then(response => response.json())
              .then(data => {
                console.log('Shipping API response:', data);

                if (data.error) {
                  throw new Error(data.error);
                }

                // Update the shipping options container
                if (container && data.shipping_options) {
                  let optionsHtml = '';
                  data.shipping_options.forEach(option => {
                    optionsHtml += `
                      <div class="flex items-center p-3 border border-base-300 rounded-lg cursor-pointer hover:bg-base-200 mb-2"
                           onclick="selectShippingOption('${option.id}', ${option.cost})">
                        <input
                          type="radio"
                          name="shipping_option"
                          value="${option.id}"
                          class="radio radio-primary"
                        />
                        <div class="ml-3 flex-1">
                          <div class="flex justify-between items-center">
                            <span class="text-sm font-medium text-base-content">
                              ${option.name}
                            </span>
                            <span class="text-sm font-semibold text-base-content">
                              $${parseFloat(option.cost).toFixed(2)}
                            </span>
                          </div>
                          ${option.estimated_days ? `
                            <p class="text-xs text-base-content/60">
                              Estimated delivery: ${option.estimated_days} business days
                            </p>
                          ` : ''}
                        </div>
                      </div>
                    `;
                  });

                  container.innerHTML = optionsHtml;

                  // Store shipping options for later use
                  window.shippingOptions = data.shipping_options;
                }
              })
              .catch(error => {
                console.error('Shipping calculation error:', error);
                if (container) {
                  container.innerHTML = `
                    <div class="text-center py-4">
                      <p class="text-sm text-error">Failed to calculate shipping rates. Please try again.</p>
                    </div>
                  `;
                }
              });
            }
          }
        };

        // Function to select shipping option
        function selectShippingOption(optionId, cost) {
          console.log('Selected shipping option:', optionId, cost);

          // Update radio button
          document.querySelectorAll('input[name="shipping_option"]').forEach(radio => {
            radio.checked = radio.value === optionId;
          });

          // Update total price
          updateTotalPrice(parseFloat(cost));

          // Store selected option
          window.selectedShippingOption = { id: optionId, cost: cost };
        }

        // Register LiveView hooks
        window.CalculateShipping = CalculateShipping;

        // Function to calculate shipping with address from form
        function calculateShippingWithAddress() {
          console.log('Calculating shipping with address from form...');

          // Collect address data from the form
          const addressData = {
            name: document.getElementById('customer-name')?.value || 'Customer',
            street1: document.getElementById('address-line1')?.value || '',
            city: document.getElementById('city')?.value || '',
            state: document.getElementById('state')?.value || '',
            zip: document.getElementById('postal-code')?.value || '',
            country: document.getElementById('country')?.value || 'US'
          };

          console.log('Collected address data:', addressData);

          // Validate required fields
          if (!addressData.street1 || !addressData.city || !addressData.state || !addressData.zip) {
            alert('Please fill in all required address fields before calculating shipping.');
            return;
          }

          // Show loading state
          const container = document.getElementById('shipping-options-container');
          if (container) {
            container.innerHTML = `
              <div class="flex items-center justify-center py-4">
                <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary"></div>
                <span class="ml-2 text-sm text-base-content/70">Calculating shipping rates...</span>
              </div>
            `;
          }

          // Make API call to calculate shipping
          fetch('/api/calculate-shipping', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
            },
            body: JSON.stringify({
              product_id: '<%= @product.id %>',
              shipping_address: addressData
            })
          })
          .then(response => response.json())
          .then(data => {
            console.log('Shipping API response:', data);

            if (data.error) {
              throw new Error(data.error);
            }

            // Update the shipping options container
            if (container && data.shipping_options) {
              let optionsHtml = '';
              data.shipping_options.forEach(option => {
                optionsHtml += `
                  <div class="flex items-center p-3 border border-base-300 rounded-lg cursor-pointer hover:bg-base-200 mb-2"
                       onclick="selectShippingOption('${option.id}', ${option.cost})">
                    <input
                      type="radio"
                      name="shipping_option"
                      value="${option.id}"
                      class="radio radio-primary"
                    />
                    <div class="ml-3 flex-1">
                      <div class="flex justify-between items-center">
                        <span class="text-sm font-medium text-base-content">
                          ${option.name}
                        </span>
                        <span class="text-sm font-semibold text-base-content">
                          $${parseFloat(option.cost).toFixed(2)}
                        </span>
                      </div>
                      ${option.estimated_days ? `
                        <p class="text-xs text-base-content/60">
                          Estimated delivery: ${option.estimated_days} business days
                        </p>
                      ` : ''}
                    </div>
                  </div>
                `;
              });

              container.innerHTML = optionsHtml;

              // Store shipping options for later use
              window.shippingOptions = data.shipping_options;
            }
          })
          .catch(error => {
            console.error('Shipping calculation error:', error);
            if (container) {
              container.innerHTML = `
                <div class="text-center py-4">
                  <p class="text-sm text-error">Failed to calculate shipping rates. Please try again.</p>
                </div>
              `;
            }
          });
        }

        // Function to select shipping option
        function selectShippingOption(optionId, cost) {
          console.log('Selected shipping option:', optionId, cost);

          // Update radio button
          document.querySelectorAll('input[name="shipping_option"]').forEach(radio => {
            radio.checked = radio.value === optionId;
          });

          // Update total price
          updateTotalPrice(parseFloat(cost));

          // Store selected option
          window.selectedShippingOption = { id: optionId, cost: cost };
        }

        // Fallback test
        setTimeout(function() {
          testStripe();
          setupDonationToggle();
        }, 2000);
      </script>
    </div>
    """
  end


  @impl true
  def handle_event("process_payment", _params, socket) do
    # This will be handled by the JavaScript on the client side
    {:noreply, socket}
  end

  def handle_event("calculate_shipping", params, socket) do
    require Logger

    Logger.info("=== CHECKOUT - CALCULATE SHIPPING EVENT ===")
    Logger.info("Product type: #{socket.assigns.product.type}")
    Logger.info("Product: #{inspect(socket.assigns.product)}")
    Logger.info("Params: #{inspect(params)}")

    if socket.assigns.product.type == "physical" do
      # Use address data from JavaScript or fallback to default
      address_data = case params do
        %{"street1" => street1} when street1 != "" ->
          %{
            "name" => Map.get(params, "name", "Customer"),
            "street1" => street1,
            "city" => Map.get(params, "city", ""),
            "state" => Map.get(params, "state", ""),
            "zip" => Map.get(params, "zip", ""),
            "country" => Map.get(params, "country", "US")
          }
        _ ->
          # Fallback to default address if no form data
          %{
            "name" => "Customer",
            "street1" => "123 Main St",
            "city" => "New York",
            "state" => "NY",
            "zip" => "10001",
            "country" => "US"
          }
      end

      Logger.info("Using address: #{inspect(address_data)}")

      socket = assign(socket, :shipping_loading, true)

      # Send async message to calculate shipping
      Logger.info("Sending async message to calculate shipping...")
      send(self(), {:calculate_shipping, address_data})

      {:noreply, socket}
    else
      Logger.info("Digital product - no shipping calculation needed")
      {:noreply, socket}
    end
  end

  def handle_event("select_shipping_option", %{"option_id" => option_id}, socket) do
    require Logger

    Logger.info("=== SELECTING SHIPPING OPTION ===")
    Logger.info("Option ID: #{option_id}")
    Logger.info("Available options: #{inspect(socket.assigns.shipping_options)}")

    selected_option = Enum.find(socket.assigns.shipping_options, &(&1.id == option_id))

    Logger.info("Selected option: #{inspect(selected_option)}")

    if selected_option do
      # Convert cost to float if it's a string
      shipping_cost = if is_binary(selected_option.cost), do: String.to_float(selected_option.cost), else: selected_option.cost

      socket =
        socket
        |> assign(:selected_shipping_option, selected_option)
        |> assign(:shipping_cost, shipping_cost)

      Logger.info("Updated shipping cost: #{shipping_cost}")
      {:noreply, socket}
    else
      Logger.error("Shipping option not found!")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:calculate_shipping, shipping_address}, socket) do
    require Logger

    Logger.info("=== CHECKOUT - HANDLE INFO CALCULATE SHIPPING ===")
    Logger.info("Shipping address: #{inspect(shipping_address)}")
    Logger.info("Product: #{inspect(socket.assigns.product)}")

      # Use store's ZIP code for shipping calculation
      store_address = case socket.assigns.product.store.shipping_zip_code do
        nil -> %{
          "name" => socket.assigns.product.store.name,
          "street1" => "123 Main St",
          "city" => "San Francisco",
          "state" => "CA",
          "zip" => "94105",
          "country" => "US"
        }
        zip_code ->
          base_address = Shomp.ZipCodeLookup.create_address_from_zip(zip_code)
          Map.merge(base_address, %{
            "name" => socket.assigns.product.store.name,
            "street1" => "123 Main St"
          })
      end

    Logger.info("Using store address: #{inspect(store_address)}")

    case ShippingCalculator.calculate_product_shipping(socket.assigns.product, shipping_address, store_address) do
      {:ok, shipping_options} ->
        Logger.info("Shipping calculation successful!")
        Logger.info("Shipping options: #{inspect(shipping_options)}")

        socket =
          socket
          |> assign(:shipping_options, shipping_options)
          |> assign(:shipping_loading, false)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Shipping calculation failed: #{inspect(reason)}")

        socket =
          socket
          |> assign(:shipping_loading, false)
          |> put_flash(:error, "Failed to calculate shipping rates. Please try again.")

        {:noreply, socket}
    end
  end


  # Helper function to generate universal order ID
  defp generate_universal_order_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :crypto.strong_rand_bytes(6) |> Base.encode64(padding: false) |> String.slice(0, 8)
    "UO_#{timestamp}_#{random}"
  end

  # Helper function to format decimal amounts for display
  defp format_amount(amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  # Helper function to format shipping cost (handles both string and float)
  defp format_cost(cost) do
    cost
    |> (fn c -> if is_binary(c), do: String.to_float(c), else: c end).()
    |> :erlang.float_to_binary(decimals: 2)
  end
end
