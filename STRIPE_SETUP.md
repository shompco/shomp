# Stripe Integration Setup Guide

## Overview
This guide will help you set up Stripe integration for the Shomp application to enable payment processing.

## Prerequisites
1. A Stripe account (sign up at [stripe.com](https://stripe.com))
2. Access to your Stripe Dashboard
3. Environment variables configured

## Step 1: Get Your Stripe API Keys

### 1.1 Log into Stripe Dashboard
- Go to [dashboard.stripe.com](https://dashboard.stripe.com)
- Sign in with your Stripe account

### 1.2 Navigate to Developers > API Keys
- In the left sidebar, click "Developers"
- Click "API keys"

### 1.3 Copy Your Keys
You'll see two keys:
- **Publishable key** (starts with `pk_test_` or `pk_live_`)
- **Secret key** (starts with `sk_test_` or `sk_live_`)

**Important**: Keep your secret key secure and never commit it to version control!

## Step 2: Set Up Environment Variables

### 2.1 Create a `.env` file (if you don't have one)
```bash
# Stripe Configuration
STRIPE_SECRET_KEY=sk_test_your_test_secret_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here
```

### 2.2 Or set them directly in your shell
```bash
export STRIPE_SECRET_KEY="sk_test_your_test_secret_key_here"
export STRIPE_WEBHOOK_SECRET="whsec_your_webhook_secret_here"
```

## Step 3: Configure Webhooks

### 3.1 Go to Webhooks in Stripe Dashboard
- In the left sidebar, click "Developers"
- Click "Webhooks"

### 3.2 Add Endpoint
- Click "Add endpoint"
- Set the endpoint URL to: `https://yourdomain.com/payments/webhook`
- For local development, you can use a service like ngrok or Stripe CLI

### 3.3 Select Events
Select these events to listen for:
- `checkout.session.completed`
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `account.updated` (for Stripe Connect account status updates)

### 3.4 Get Webhook Secret
After creating the webhook, click on it and copy the "Signing secret" (starts with `whsec_`)

## Step 4: Stripe Connect Setup

### 4.1 Enable Stripe Connect (Test Mode)
1. Go to your Stripe Dashboard
2. **Make sure you're in Test Mode** (toggle in the top-left corner)
3. Navigate to "Connect" in the left sidebar
4. Click "Get started" to enable Stripe Connect
5. Choose "Express accounts" for the simplest onboarding experience

### 4.2 Configure Connect Settings
1. In the Connect settings, set up your platform information
2. Configure your branding and terms of service
3. Set up your payout schedule (recommended: daily or weekly)
4. **For testing**: You can use placeholder information like "Test Platform" for your business name

### 4.3 Testing Stripe Connect in Sandbox Mode
**Important**: Stripe Connect works perfectly in test mode! Here's what you can test:

- ✅ **Account Creation**: Create test Connect accounts
- ✅ **Onboarding Flow**: Complete the full Stripe-hosted onboarding
- ✅ **Identity Verification**: Test with fake documents and information
- ✅ **Account Status Updates**: Receive webhooks for account changes
- ✅ **Payout Simulation**: Test payout flows (no real money moves)
- ✅ **API Integration**: All Connect API calls work in test mode

**Test Data You Can Use:**
- Use any fake business information during onboarding
- Upload any image files as "documents" (they don't need to be real)
- Use test bank account numbers (see below)
- All verification steps will complete successfully in test mode

**Test Bank Account Numbers:**
- **US Bank Account**: `000123456789` (routing: `110000000`)
- **US Bank Account (ACH)**: `000123456789` (routing: `110000000`)
- **International**: Use any fake account numbers for non-US accounts

**Test Credit Cards for Connect Testing:**
- `4242424242424242` - Visa (succeeds)
- `4000000000000002` - Visa (declined)
- `4000000000009995` - Visa (insufficient funds)

## Step 5: Test the Integration

### 5.1 Start Your Application
```bash
mix phx.server
```

### 5.2 Create a Test Product
1. Go to `/stores/new` and create a store
2. Go to `/dashboard/products/new` and create a product
3. Set a price (e.g., $9.99)

### 5.3 Test Stripe Connect Onboarding
1. Go to your store's balance page (`/stores/{store_id}/balance`)
2. Click "Start Stripe Onboarding" in the KYC Status section
3. Complete the Stripe-hosted onboarding flow with test data:
   - Use any fake business name and address
   - Upload any image file as your ID document
   - Use the test bank account number: `000123456789` (routing: `110000000`)
4. Complete all steps in the onboarding flow
5. Return to the balance page to see the updated status
6. **Check your webhook logs** to see the `account.updated` events being received

### 5.4 Test Webhook Events (Optional)
To test webhook events locally, you can use Stripe CLI:
```bash
# Install Stripe CLI
stripe listen --forward-to localhost:4000/payments/webhook

# In another terminal, trigger test events
stripe trigger account.updated
```

### 5.5 Test the Buy Button
1. Go to the product page
2. Click "Buy Now"
3. You should see a message "Checkout functionality coming soon!"

## Step 6: Enable Live Checkout (Optional)

### 6.1 Update the Buy Now Button
Currently, the Buy Now button shows a placeholder message. To enable actual Stripe checkout:

1. **Update the product show page** (`lib/shomp_web/live/product_live/show.ex`)
2. **Implement the checkout flow** in the `buy_now` event handler
3. **Add Stripe.js** to your frontend for secure payment processing

### 5.2 Example Implementation
```elixir
def handle_event("buy_now", _params, socket) do
  # Create Stripe checkout session
  case Payments.create_checkout_session(
    socket.assigns.product.id,
    socket.assigns.current_scope.user.id,
    ~p"/payments/success",
    ~p"/payments/cancel"
  ) do
    {:ok, session, _payment} ->
      # Redirect to Stripe Checkout
      {:noreply, push_navigate(socket, external: session.url)}
    
    {:error, _reason} ->
      {:noreply, put_flash(socket, :error, "Failed to create checkout session")}
  end
end
```

## Step 6: Production Considerations

### 6.1 Switch to Live Keys
When ready for production:
1. Replace test keys with live keys
2. Update webhook endpoints to production URLs
3. Test thoroughly in Stripe's test mode first

### 6.2 Security Best Practices
1. **Never expose secret keys** in client-side code
2. **Always verify webhook signatures** (already implemented)
3. **Use HTTPS** for all payment-related endpoints
4. **Implement proper error handling** and logging

### 6.3 Compliance
1. **PCI Compliance**: Stripe handles most PCI requirements
2. **GDPR**: Ensure proper data handling for EU customers
3. **Local Regulations**: Check payment laws in your jurisdiction

## Troubleshooting

### Common Issues

#### 1. "Invalid API key" error
- Check that `STRIPE_SECRET_KEY` is set correctly
- Ensure you're using the right key (test vs live)

#### 2. Webhook signature verification fails
- Verify `STRIPE_WEBHOOK_SECRET` is correct
- Check that webhook endpoint URL matches exactly

#### 3. Payment creation fails
- Check database migrations have been run
- Verify product and user associations exist

### Getting Help
- [Stripe Documentation](https://stripe.com/docs)
- [Stripe Support](https://support.stripe.com)
- [Stripe Community](https://community.stripe.com)

## Next Steps

Once basic Stripe integration is working:

1. **Implement product delivery** for digital products
2. **Add order management** and customer support
3. **Implement subscription billing** if needed
4. **Add analytics** and reporting
5. **Implement refunds** and dispute handling

## Security Notes

- **Never log payment details** (card numbers, etc.)
- **Always use HTTPS** in production
- **Implement rate limiting** on payment endpoints
- **Monitor for suspicious activity**
- **Keep dependencies updated**

---

**Remember**: This is a basic implementation. For production use, consider additional security measures, error handling, and compliance requirements.
