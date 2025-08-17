# Shomp MVP - Elixir Feature Breakdown

## 1. User Auth (Shomp.Accounts)
### Context & Schema
- `Shomp.Accounts.User` schema (email, password_hash, name, role)
- `Shomp.Accounts` context functions (register_user, authenticate, get_user)

### Web Layer
- `ShompWeb.UserRegistrationController` (new, create)
- `ShompWeb.UserSessionController` (new, create, delete)
- `ShompWeb.UserRegistrationLive` (LiveView registration form)
- `ShompWeb.UserLoginLive` (LiveView login form)

### Auth Pipeline
- `ShompWeb.UserAuth` plug module
- `require_authenticated_user/2` plug
- Session management functions

## 2. Create Store (Shomp.Stores)
### Context & Schema
- `Shomp.Stores.Store` schema (name, slug, description, user_id)
- `Shomp.Stores` context (create_store, get_store_by_slug, update_store)

### Web Layer
- `ShompWeb.StoreLive.New` (create store form)
- `ShompWeb.StoreLive.Show` (public store page)
- `ShompWeb.StoreLive.Edit` (edit store settings)

### Routes
- `/stores/new` - create store
- `/:store_slug` - public store page
- `/dashboard/store` - edit store

## 3. Create Product Listing (Shomp.Products)
### Context & Schema
- `Shomp.Products.Product` schema (title, description, price, type, file_path, store_id)
- `Shomp.Products` context (create_product, list_products, get_product)

### File Upload
- `Shomp.Uploads` module for handling product files
- S3/local storage configuration
- Image processing with Mogrify

### Web Layer
- `ShompWeb.ProductLive.New` (create product form)
- `ShompWeb.ProductLive.Show` (product detail page)
- `ShompWeb.ProductLive.Edit` (edit product)

### Routes
- `/dashboard/products/new` - create product
- `/:store_slug/products/:id` - product page
- `/dashboard/products/:id/edit` - edit product

## 4. Stripe Buy Now Button (Shomp.Payments)
### Context & Schema
- `Shomp.Payments.Payment` schema (amount, stripe_payment_id, product_id, user_id)
- `Shomp.Payments` context (create_checkout_session, handle_webhook)

### Stripe Integration
- Stripe API client configuration
- Checkout session creation
- Webhook endpoint handling
- Payment confirmation

### Web Layer
- `ShompWeb.PaymentController` (create_checkout, webhook)
- Buy now button component
- Payment success/cancel pages

### Routes
- `/payments/checkout` - create Stripe session
- `/payments/webhook` - Stripe webhooks
- `/payments/success` - payment success
- `/payments/cancel` - payment cancelled

## 5. Product Download After Purchase (Shomp.Downloads)
### Context & Schema
- `Shomp.Downloads.Download` schema (product_id, user_id, download_count, expires_at)
- `Shomp.Downloads` context (create_download_link, verify_access)

### Secure Download
- Signed URL generation
- Download limit enforcement
- Access verification middleware

### Web Layer
- `ShompWeb.DownloadController` (show, download)
- Download link generation after payment
- Protected file serving

### Routes
- `/downloads/:token` - secure download link
- `/purchases` - user's purchased products

## 6. Addresses for Physical Products (Shomp.Addresses)
### Context & Schema
- `Shomp.Addresses.Address` schema (street, city, state, zip, country, user_id)
- `Shomp.Addresses` context (create_address, get_user_addresses)

### Integration
- Address form in checkout flow
- Address validation
- Shipping address storage

### Web Layer
- `ShompWeb.AddressLive.Form` (address input component)
- Address management in user dashboard
- Checkout address selection

### Routes
- `/dashboard/addresses` - manage addresses
- Embedded in checkout flow

## 7. Donation Page (Shomp.Donations)
### Context & Schema
- `Shomp.Donations.Donation` schema (amount, recurring, stripe_subscription_id, user_id)
- `Shomp.Donations` context (create_donation, create_subscription)

### Stripe Integration
- One-time payment processing
- Subscription creation for recurring
- Webhook handling for subscription events

### Web Layer
- `ShompWeb.DonationLive` (donation form with amount selection)
- `ShompWeb.DonationController` (process donation)
- Thank you page after donation

### Routes
- `/support` - donation page
- `/donations/process` - handle donation
- `/donations/thank-you` - success page

## Supporting Infrastructure
### Database
- Ecto migrations for all schemas
- Database indexes for performance
- Foreign key constraints

### Configuration
- Stripe API keys in config
- File upload configuration
- Email configuration

### Background Jobs
- Oban for background processing
- Email sending jobs
- Webhook processing jobs