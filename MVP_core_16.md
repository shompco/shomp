# Shomp MVP Core 16 - Miscellaneous Platform Features

## Overview
This MVP covers the remaining miscellaneous features needed to complete the platform, including newsletter integration, audience management, and additional notification systems.

## Core Features

### 1. Newsletter Signup Integration
- **Beehiiv Integration**: Connect to Beehiiv API for newsletter management
- **Page Footer Signup**: Add newsletter signup forms to all page footers
- **Store Page Signup**: Newsletter signup on individual store pages
- **Email Collection**: Secure email collection and validation
- **Subscription Management**: Handle subscribe/unsubscribe events

### 2. Audience Management System
- **Creator Email Lists**: Each creator can build their own email audience
- **Profile Integration**: Add audience management to user profile pages
- **Email Tracking**: Track email signups per creator/store
- **Audience Analytics**: Basic analytics for email list growth
- **Opt-in Management**: Proper consent and opt-out handling

### 3. Enhanced SMS Notifications
- **MessageBird Integration**: SMS notifications using MessageBird API
- **Physical Order Alerts**: SMS to sellers for new physical product sales
- **Order Status Updates**: SMS notifications for order status changes
- **Phone Number Collection**: Add phone number field to user profiles
- **SMS Preferences**: User control over SMS notifications

### 4. Comprehensive Email Notifications
- **Email Templates**: Professional HTML email templates
- **Transactional Emails**: Order confirmations, receipts, shipping updates
- **Marketing Emails**: Product updates, promotions, newsletters
- **Admin Notifications**: System alerts and reports
- **Email Delivery**: Reliable email delivery with bounce handling

### 5. Notification Preferences System
- **User Control Panel**: Notification preferences page
- **Channel Selection**: Choose email, SMS, in-app notifications
- **Frequency Settings**: Control notification frequency
- **Quiet Hours**: Set quiet hours for notifications
- **Unsubscribe Management**: Easy unsubscribe options

## Implementation Tasks

### Phase 1: Newsletter & Audience Management
1. **Beehiiv API Integration**
   - Add Beehiiv SDK to dependencies
   - Configure API keys and authentication
   - Create newsletter context for subscriber management
   - Handle API rate limiting and error handling

2. **Newsletter Signup Forms**
   - Add signup component to page footer
   - Add signup form to store pages
   - Email validation and submission handling
   - Success/error messaging and feedback

3. **Audience Management**
   - Add audience management section to user profiles
   - Track email signups per creator
   - Display audience growth metrics
   - Manage subscriber lists and preferences

### Phase 2: SMS Notifications
1. **MessageBird Integration**
   - Add MessageBird SDK to dependencies
   - Configure SMS API keys
   - Create SMS context for message sending
   - Handle SMS delivery and error tracking

3. **SMS Notification System**
   - SMS alerts to Seller for new physical orders


### Phase 3: Email Notification System


### Phase 4: Notification Preferences
1. **Preferences Database Schema**
   - Notification preferences table
   - User preferences page


3. **Admin Controls**
   - Delivery monitoring dashboard

## Database Schema

### Newsletter Subscriptions Table
```elixir
create table(:newsletter_subscriptions) do
  add :id, :bigserial, primary_key: true
  add :email, :string, null: false
  add :user_id, references(:users, type: :bigserial), null: true
  add :store_id, references(:stores, type: :string), null: true
  add :beehiiv_subscriber_id, :string
  add :status, :string, default: "active" # active, unsubscribed, bounced
  add :subscribed_at, :utc_datetime, null: false
  add :unsubscribed_at, :utc_datetime, null: true
  
  timestamps()
end

create unique_index(:newsletter_subscriptions, [:email, :store_id])
create index(:newsletter_subscriptions, [:user_id])
create index(:newsletter_subscriptions, [:store_id])
create index(:newsletter_subscriptions, [:status])
```

### SMS Notifications Table
```elixir
create table(:sms_notifications) do
  add :id, :bigserial, primary_key: true
  add :user_id, references(:users, type: :bigserial), null: false
  add :phone_number, :string, null: false
  add :message, :text, null: false
  add :message_type, :string, null: false # order_alert, status_update, shipping
  add :order_id, references(:universal_orders, type: :string), null: true
  add :messagebird_id, :string
  add :status, :string, default: "pending" # pending, sent, delivered, failed
  add :sent_at, :utc_datetime, null: true
  add :delivered_at, :utc_datetime, null: true
  
  timestamps()
end

create index(:sms_notifications, [:user_id])
create index(:sms_notifications, [:order_id])
create index(:sms_notifications, [:status])
create index(:sms_notifications, [:message_type])
```

### Notification Preferences Table
```elixir
create table(:notification_preferences) do
  add :user_id, references(:users, type: :bigserial), primary_key: true
  add :email_enabled, :boolean, default: true
  add :sms_enabled, :boolean, default: true
  add :in_app_enabled, :boolean, default: true
  add :order_updates, :boolean, default: true
  add :marketing_emails, :boolean, default: false
  add :product_updates, :boolean, default: true
  add :newsletter_emails, :boolean, default: true
  add :admin_alerts, :boolean, default: true
  
  timestamps()
end
```

