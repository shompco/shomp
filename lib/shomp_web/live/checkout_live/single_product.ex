defmodule ShompWeb.CheckoutLive.SingleProduct do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Products
  alias Shomp.Stores
  alias Shomp.UniversalOrders
  alias Shomp.PaymentSplits
  alias Shomp.UniversalOrderItems

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
      store_slug: store_slug
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
            <%= if @from == "cart" do %>
              <.link 
                navigate={~p"/cart"}
                class="text-primary hover:text-primary-focus transition-colors"
              >
                ← Back to Cart
              </.link>
            <% else %>
              <.link 
                navigate={~p"/stores/#{@product.store.slug}"}
                class="text-primary hover:text-primary-focus transition-colors"
              >
                ← Back to Store
              </.link>
            <% end %>
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
                <%= if @product.image_thumb do %>
                  <img 
                    src={@product.image_thumb} 
                    alt={@product.title}
                    class="w-16 h-16 object-cover rounded-lg"
                  />
                <% end %>
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
                <div class="total-row flex justify-between items-center text-lg font-semibold">
                  <span>Total</span>
                  <span class="total-amount">$<%= if @donate, do: format_amount(@total_amount), else: format_amount(@product.price) %></span>
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
                    <%= if @product.type == "physical", do: "Complete Order", else: "Complete Purchase" %> - $<%= if @donate, do: format_amount(@total_amount), else: format_amount(@product.price) %>
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
        
        // Collect form data
        function collectFormData() {
          const formData = {
            product_id: '<%= @product.id %>',
            universal_order_id: '<%= @universal_order_id %>',
            donate: <%= @donate %>,
            customer_email: document.getElementById('customer-email').value,
            customer_name: document.getElementById('customer-name').value
          };
          
          // Add shipping address for physical products
          <% if @product.type == "physical" do %>
          formData.shipping_address = {
            line1: document.getElementById('address-line1').value,
            line2: document.getElementById('address-line2').value,
            city: document.getElementById('city').value,
            state: document.getElementById('state').value,
            postal_code: document.getElementById('postal-code').value,
            country: document.getElementById('country').value
          };
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
          
          <% if @product.type == "physical" do %>
          // Shipping address validation
          if (!formData.shipping_address.line1) {
            errors.push('Street address is required');
          } else if (formData.shipping_address.line1.trim().length < 5) {
            errors.push('Please enter a complete street address');
          }
          
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
          
          const submitButton = document.getElementById('submit-payment');
          if (!submitButton || !stripe || !cardElement) {
            console.error('Payment system not ready');
            return;
          }
          
          // Collect and validate form data
          const formData = collectFormData();
          const validationErrors = validateFormData(formData);
          
          if (validationErrors.length > 0) {
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
            // Create payment intent
            const response = await fetch('/api/create-payment-intent', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
              },
              body: JSON.stringify(formData)
            });
            
            const data = await response.json();
            
            if (data.error) {
              throw new Error(data.error);
            }
            
            // Confirm payment
            const result = await stripe.confirmCardPayment(data.client_secret, {
              payment_method: {
                card: cardElement,
                billing_details: {
                  name: formData.customer_name,
                  email: formData.customer_email,
                  <% if @product.type == "physical" do %>
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
            
            if (result.error) {
              const displayError = document.getElementById('card-errors');
              if (displayError) {
                displayError.textContent = result.error.message;
              }
              
              // Re-enable button
              submitButton.disabled = false;
              updateButtonText();
            } else {
              // Payment succeeded - redirect to processing page
              window.location.href = '/checkout/processing/' + result.paymentIntent.id;
            }
            
          } catch (error) {
            console.error('Payment error:', error);
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
end
