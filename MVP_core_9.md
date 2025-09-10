# Shomp MVP Core 9 - Email Collection & Seller Notifications

# Gumroad-Style Email Collection for Product Pages
# Email collection system to build seller followings and product notifications

## 1. Email Subscription System (Shomp.EmailSubscriptions)
### Context & Schema
- `Shomp.EmailSubscriptions.EmailSubscription` schema (immutable_id, email, store_id, product_id, status, subscribed_at, unsubscribed_at, created_at, updated_at)
- Status: active, unsubscribed, bounced
- Store-level and product-level subscriptions
- `Shomp.EmailSubscriptions` context (subscribe_email, unsubscribe_email, get_subscribers, send_notification, validate_email)

### Email Collection Features
- Fixed footer on product pages for email collection
- "Get notified of new products from this seller" messaging
- Store-specific email lists
- Product-specific email lists
- Double opt-in email verification
- Unsubscribe functionality
- Email validation and sanitization

## 2. Product Page Email Collection UI
### Fixed Footer Component
- Sticky footer on product pages
- Clean, non-intrusive design
- Email input field with validation
- "Get notified of new products from this seller" text
- Subscribe button with loading state
- Success/error messaging
- GDPR-compliant consent checkbox

### Visual Design
- Matches product page styling
- Positioned at bottom of viewport
- Semi-transparent background
- Smooth slide-up animation
- Mobile-responsive design
- Dismissible after successful subscription

## 3. Email Management & Analytics
### Store Owner Dashboard
- View subscriber count per store
- View subscriber count per product
- Export subscriber lists (CSV)
- Email engagement metrics
- Unsubscribe rate tracking
- Bounce rate monitoring

### Email Notifications
- New product launch notifications
- Product update notifications
- Store announcement emails
- Automated welcome emails
- Unsubscribe confirmation emails

## 4. Database Schema & Migrations
### EmailSubscriptions Table
```elixir
create table(:email_subscriptions) do
  add :immutable_id, :string, null: false
  add :email, :string, null: false
  add :store_id, references(:stores, type: :string), null: false
  add :product_id, references(:products, type: :bigserial), null: true
  add :status, :string, default: "active", null: false
  add :subscribed_at, :utc_datetime, null: false
  add :unsubscribed_at, :utc_datetime, null: true
  add :verification_token, :string, null: true
  add :verified_at, :utc_datetime, null: true
  
  timestamps()
end

create unique_index(:email_subscriptions, [:email, :store_id])
create index(:email_subscriptions, [:store_id])
create index(:email_subscriptions, [:product_id])
create index(:email_subscriptions, [:status])
```

## 5. Email Verification System
### Double Opt-In Process
- Send verification email after subscription
- Unique verification token per subscription
- 24-hour token expiration
- Verified status tracking
- Resend verification functionality

### Email Templates
- Welcome email with verification link
- Verification success confirmation
- Unsubscribe confirmation
- New product notification template
- Store announcement template

## 6. Privacy & Compliance
### GDPR Compliance
- Clear consent language
- Easy unsubscribe process
- Data retention policies
- Right to be forgotten implementation
- Privacy policy integration

### Email Security
- Email validation and sanitization
- Rate limiting on subscriptions
- Spam prevention measures
- Secure token generation
- HTTPS-only verification links

## 7. Integration Points
### Product Page Integration
- `ProductLive.Show` component updates
- Fixed footer component
- Email collection form
- Success/error state management
- Store context passing

### Store Dashboard Integration
- Subscriber analytics
- Email management tools
- Notification sending interface
- Export functionality
- Engagement metrics

## 8. Technical Implementation
### Context Functions
```elixir
defmodule Shomp.EmailSubscriptions do
  def subscribe_email(email, store_id, product_id \\ nil)
  def unsubscribe_email(email, store_id)
  def verify_subscription(token)
  def get_store_subscribers(store_id)
  def get_product_subscribers(product_id)
  def send_product_notification(store_id, product_id, message)
  def export_subscribers(store_id, format \\ :csv)
end
```

### LiveView Components
- `EmailSubscriptionForm` component
- `SubscriberAnalytics` component
- `EmailNotificationForm` component
- `SubscriberExport` component

## 9. Success Metrics
### Key Performance Indicators
- Email subscription rate per product page
- Email verification completion rate
- Unsubscribe rate
- Email open rates
- Click-through rates on product notifications
- Store follower growth rate

### Analytics Dashboard
- Real-time subscription metrics
- Historical growth charts
- Store comparison analytics
- Product performance metrics
- Email engagement tracking

## 10. Future Enhancements
### Advanced Features
- Segmented email lists
- Automated email sequences
- A/B testing for email copy
- Integration with external email services
- Advanced analytics and reporting
- Email template customization
- Scheduled email campaigns

### Integration Opportunities
- Social media integration
- Push notification system
- SMS notifications
- WhatsApp notifications
- Discord/Slack integration
