# Shomp MVP - Elixir Feature Breakdown

# Never expose user emails
# Never expose user fullname

## 1. User Auth & Tiers (Shomp.Accounts)
### Context & Schema
- users get immutable id
- `Shomp.Accounts.User` schema (immutable_id, email, password_hash, name, role, tier, created_at, updated_at)
- `Shomp.Accounts.Tier` schema (name, store_limit, product_limit_per_store, monthly_price, features)
- `Shomp.Accounts` context functions (register_user, authenticate, get_user, upgrade_tier)

### Tiers
- Free: 1 store, 100 products per store, $0/month
- Plus: 3 stores, 500 products per store, $10/month  
- Pro: 5-10 stores, 1000 products per store, $20/month, priority support

### Web Layer
- `ShompWeb.UserRegistrationController` (new, create)
- `ShompWeb.UserSessionController` (new, create, delete)
- `ShompWeb.UserRegistrationLive` (LiveView registration form with tier selection)
- `ShompWeb.UserLoginLive` (LiveView login form)
- `ShompWeb.TierUpgradeLive` (tier upgrade/downgrade interface)

### Auth Pipeline
- `ShompWeb.UserAuth` plug module
- `require_authenticated_user/2` plug
- Session management functions
- Magic link authentication support

## 2. Create Store (Shomp.Stores)
### Context & Schema
- stores get immutable id
- `Shomp.Stores.Store` schema (immutable_id, name, slug, description, user_id, created_at, updated_at)
- `Shomp.Stores` context (create_store, get_store_by_slug, update_store, check_store_limit)

### Web Layer
- `ShompWeb.StoreLive.New` (create store form)
- `ShompWeb.StoreLive.Show` (public store page)
- `ShompWeb.StoreLive.Edit` (edit store settings)

### Routes
- `/stores/new` - create store
- `/:store_slug` - public store page
- `/dashboard/store` - edit store
- `/stores` - show all the stores we have
- place the catch-all slug at the bottom of the router

## 3. Categories (Shomp.Categories)
### Context & Schema
- `Shomp.Categories.Category` schema (immutable_id, name, slug, parent_id, position, active, description, level, created_at, updated_at)
- Self-referencing hierarchy with parent_id for unlimited nesting
- Seed with Etsy's 18 main categories: Accessories, Art & Collectibles, Bags & Purses, Bath & Beauty, Books Movies & Music, Clothing, Craft Supplies & Tools, Electronics & Accessories, Home & Living, Jewelry, Paper & Party Supplies, Pet Supplies, Shoes, Toys & Games, Weddings, Baby, Gifts

### Web Layer
- `ShompWeb.CategoryLive.Index` (browse categories)
- `ShompWeb.CategoryLive.Show` (category page with products)
- Admin interface for category management

### Routes
- `/categories` - browse all categories
- `/categories/:slug` - category page
- `/admin/categories` - admin category management

## 4. Create Product Listing (Shomp.Products)
### Context & Schema
- products get immutable id and human readable slug 
- `Shomp.Products.Product` schema (immutable_id, title, slug, description, price, type, file_path, store_id, category_id, subcategory_id, status, inventory_count, weight, created_at, updated_at)
- Status: draft, published, archived
- `Shomp.Products` context (create_product, list_products, get_product, check_product_limit)

### File Upload
- `Shomp.Uploads` module for handling product files
- S3/local storage configuration
- Image processing with Mogrify

### Web Layer
- `ShompWeb.ProductLive.New` (create product form with category selection)
- `ShompWeb.ProductLive.Show` (product detail page)
- `ShompWeb.ProductLive.Edit` (edit product)

### Routes
- `/dashboard/products/new` - create product
- `/:store_slug/products/:id` - product page by ID
- `/:store_slug/products/:slug` - product page by slug
- `/dashboard/products/:id/edit` - edit product

## 5. Shopping Cart (Shomp.Carts)
### Context & Schema
- `Shomp.Carts.Cart` schema (immutable_id, user_id, session_id, created_at, updated_at)
- `Shomp.Carts.CartItem` schema (cart_id, product_id, quantity, price_snapshot, created_at)
- `Shomp.Carts` context (add_to_cart, remove_from_cart, get_cart, clear_cart)

### Web Layer
- `ShompWeb.CartLive` (shopping cart page)
- `ShompWeb.Components.AddToCart` (add to cart button component)
- Cart icon with item count in header

### Routes
- `/cart` - shopping cart page
- `/cart/add` - add item to cart
- `/cart/remove` - remove item from cart

## 6. Orders & Checkout (Shomp.Orders)
### Context & Schema
- `Shomp.Orders.Order` schema (immutable_id, user_id, total_amount, status, billing_address_id, shipping_address_id, created_at, updated_at)
- `Shomp.Orders.OrderItem` schema (order_id, product_id, quantity, price, created_at)
- Status: pending, processing, shipped, delivered, cancelled
- `Shomp.Orders` context (create_order, update_status, get_order)

### Web Layer
- `ShompWeb.CheckoutLive` (checkout process)
- `ShompWeb.OrderLive.Show` (order confirmation)
- `ShompWeb.OrderLive.Index` (order history)

### Routes
- `/checkout` - checkout process
- `/orders/:id` - order confirmation
- `/dashboard/orders` - order history

## 7. Stripe Payments (Shomp.Payments)
### Context & Schema
- `Shomp.Payments.Payment` schema (immutable_id, amount, stripe_payment_id, order_id, user_id, status, created_at)
- `Shomp.Payments.StripeAccount` schema (user_id, stripe_account_id, onboarding_complete, kyc_verified)
- `Shomp.Payments` context (create_checkout_session, handle_webhook, onboard_seller)

### Stripe Integration
- Stripe API client configuration
- Checkout session creation
- Webhook endpoint handling
- Stripe Connect for seller payouts
- KYC verification for US sellers only

### Web Layer
- `ShompWeb.PaymentController` (create_checkout, webhook)
- `ShompWeb.StripeOnboardingLive` (seller onboarding)
- Buy now button component
- Payment success/cancel pages

### Routes
- `/payments/checkout` - create Stripe session
- `/payments/webhook` - Stripe webhooks
- `/payments/success` - payment success
- `/payments/cancel` - payment cancelled
- `/dashboard/stripe/onboard` - seller onboarding

## 8. Seller Dashboard & Balance (Shomp.Earnings)
### Context & Schema
- `Shomp.Earnings.Earning` schema (seller_id, order_id, amount, commission, net_amount, payout_date, created_at)
- `Shomp.Earnings` context (calculate_earnings, get_balance, process_payouts)

### Web Layer
- `ShompWeb.DashboardLive` (seller earnings overview)
- `ShompWeb.EarningsLive` (detailed earnings report)
- Balance display with pending/available amounts

### Routes
- `/dashboard` - seller dashboard
- `/dashboard/earnings` - earnings breakdown

## 9. Reviews & Ratings (Shomp.Reviews)
### Context & Schema
- `Shomp.Reviews.Review` schema (immutable_id, product_id, user_id, order_id, rating, review_text, helpful_count, verified_purchase, created_at, updated_at)
- `Shomp.Reviews.ReviewVote` schema (review_id, user_id, helpful, created_at)
- Rating: 1-5 star system
- `Shomp.Reviews` context (create_review, vote_helpful, get_product_reviews)

### Web Layer
- `ShompWeb.ReviewLive.Form` (review submission form)
- `ShompWeb.ReviewLive.Index` (product reviews display)
- Review components for product pages

### Routes
- `/products/:id/reviews` - product reviews
- `/dashboard/reviews` - user's submitted reviews

## 10. Messaging (Shomp.Communications)
### Context & Schema
- `Shomp.Communications.Conversation` schema (immutable_id, buyer_id, seller_id, product_id, created_at, updated_at)
- `Shomp.Communications.Message` schema (conversation_id, sender_id, content, read_at, created_at)
- `Shomp.Communications` context (create_conversation, send_message, mark_read)

### Web Layer
- `ShompWeb.MessagesLive` (messaging interface)
- `ShompWeb.ConversationLive` (individual conversation)
- Message notifications

### Routes
- `/messages` - message inbox
- `/messages/:conversation_id` - individual conversation

## 11. Product Download After Purchase (Shomp.Downloads)
### Context & Schema
- `Shomp.Downloads.Download` schema (immutable_id, product_id, user_id, order_id, download_count, download_limit, expires_at, created_at)
- `Shomp.Downloads` context (create_download_link, verify_access, track_download)

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

## 12. Addresses for Physical Products (Shomp.Addresses)
### Context & Schema
- `Shomp.Addresses.Address` schema (immutable_id, street, city, state, zip, country, user_id, type, default, created_at, updated_at)
- Type: billing, shipping
- `Shomp.Addresses` context (create_address, get_user_addresses, set_default)

### Integration
- Address form in checkout flow
- Address validation for US only
- Shipping address storage

### Web Layer
- `ShompWeb.AddressLive.Form` (address input component)
- Address management in user dashboard
- Checkout address selection

### Routes
- `/dashboard/addresses` - manage addresses
- Embedded in checkout flow

## 13. Compliance & KYC (Shomp.Compliance)
### Context & Schema
- `Shomp.Compliance.KycVerification` schema (user_id, status, submitted_at, verified_at, rejection_reason)
- US-only verification for sellers
- `Shomp.Compliance` context (submit_kyc, verify_identity, get_verification_status)

### Web Layer
- `ShompWeb.KycLive` (KYC submission form)
- Identity verification workflow
- Document upload interface

### Routes
- `/dashboard/verification` - KYC process
- `/verification/status` - verification status

## 14. Donation Page (Shomp.Donations)
### Context & Schema
- `Shomp.Donations.Donation` schema (immutable_id, amount, recurring, stripe_subscription_id, user_id, created_at)
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

## 15. Feature Requests (Shomp.FeatureRequests)
### Context & Schema
- `Shomp.FeatureRequests.Request` schema (immutable_id, title, description, category, status, user_id, priority, created_at, updated_at)
- `Shomp.FeatureRequests.Vote` schema (request_id, user_id, weight, created_at)
- `Shomp.FeatureRequests.Comment` schema (immutable_id, request_id, user_id, content, created_at)
- `Shomp.FeatureRequests` context (create_request, vote_request, add_comment, merge_requests)

### Voting & Prioritization
- Vote weight calculation based on user activity
- Admin priority override system
- Duplicate detection and merging
- Status tracking workflow

### Notification System
- Email notifications for status changes
- Comment notifications
- Request updates to submitters
- Roadmap milestone notifications

### Web Layer
- `ShompWeb.FeatureRequestLive.Index` (browse all requests)
- `ShompWeb.FeatureRequestLive.New` (submit new request)
- `ShompWeb.FeatureRequestLive.Show` (request detail with comments)
- `ShompWeb.FeatureRequestLive.Admin` (admin management interface)
- `ShompWeb.RoadmapLive` (public roadmap display)

### Routes
- `/features` - browse feature requests
- `/features/new` - submit feature request
- `/features/:id` - feature request detail
- `/features/search` - search requests
- `/dashboard/features` - user's submitted requests
- `/admin/features` - admin feature management
- `/roadmap` - public feature roadmap

## 16. Notifications (Shomp.Notifications)
### Context & Schema
- `Shomp.Notifications.Notification` schema (immutable_id, user_id, type, title, message, read_at, data, created_at)
- `Shomp.Notifications` context (create_notification, mark_read, get_unread_count)

### Web Layer
- `ShompWeb.NotificationLive` (notification center)
- Real-time notification updates
- Email notification preferences

### Routes
- `/notifications` - notification center
- `/settings/notifications` - notification preferences

## 17. Admin Panel (Shomp.Admin)
### Context & Schema
- Admin role management
- Platform analytics and reporting
- User and store management
- Category management

### Web Layer
- `ShompWeb.AdminLive.Dashboard` (admin overview)
- `ShompWeb.AdminLive.Users` (user management)
- `ShompWeb.AdminLive.Analytics` (platform metrics)

### Routes
- `/admin` - admin dashboard
- `/admin/users` - user management
- `/admin/analytics` - platform analytics