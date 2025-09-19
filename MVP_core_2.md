# Shomp MVP Core 2 - Feature Breakdown

## 1. Store Messaging System (Shomp.Messages)
### Context & Schema
- `Shomp.Messages.Conversation` schema (store_id, customer_id, subject, status, created_at, updated_at)
- `Shomp.Messages.Message` schema (conversation_id, sender_id, sender_type, content, read_at, created_at)
- `Shomp.Messages` context (create_conversation, send_message, mark_as_read, get_conversations)

### Message Types & Features
- Pre-purchase inquiries
- Post-purchase support
- Custom order requests
- General store questions
- Attachment support for images/files

### Web Layer
- `ShompWeb.MessageLive.Index` (conversation list)
- `ShompWeb.MessageLive.Show` (conversation thread)
- `ShompWeb.MessageLive.New` (start new conversation)
- `ShompWeb.Components.MessageForm` (inline message composition)
- Real-time updates with Phoenix PubSub

### Routes
- `/stores/:store_slug/contact` - message store form
- `/dashboard/messages` - store owner message inbox
- `/messages` - customer message center
- `/messages/:conversation_id` - conversation thread

## 2. Store Reviews & Ratings (Shomp.Reviews)
### Context & Schema
- `Shomp.Reviews.Review` schema (store_id, product_id, user_id, rating, title, content, verified_purchase, created_at)
- `Shomp.Reviews.ReviewResponse` schema (review_id, store_id, content, created_at)
- `Shomp.Reviews` context (create_review, respond_to_review, calculate_ratings)

### Review Features
- 5-star rating system
- Verified purchase badges
- Store owner responses
- Review moderation (flagging)
- Aggregate rating calculations
- Photo/video review uploads

### Web Layer
- `ShompWeb.ReviewLive.Form` (review submission)
- `ShompWeb.ReviewLive.Index` (store/product reviews)
- `ShompWeb.ReviewLive.Show` (individual review detail)
- Review components for store/product pages

### Routes
- `/:store_slug/reviews` - store reviews
- `/:store_slug/products/:id/reviews` - product reviews
- `/dashboard/reviews` - manage store reviews
- `/reviews/write/:product_id` - write review

## 3. Store Analytics Dashboard (Shomp.Analytics)
### Context & Schema
- `Shomp.Analytics.PageView` schema (store_id, product_id, user_id, ip_address, user_agent, created_at)
- `Shomp.Analytics.Conversion` schema (store_id, product_id, user_id, conversion_type, value, created_at)
- `Shomp.Analytics` context (track_view, track_conversion, generate_reports)

### Analytics Features
- Store visit tracking
- Product view analytics
- Conversion rate metrics
- Revenue analytics
- Customer demographics
- Traffic source tracking
- Export capabilities

### Web Layer
- `ShompWeb.AnalyticsLive.Dashboard` (main analytics dashboard)
- `ShompWeb.AnalyticsLive.Reports` (detailed reports)
- Chart components with Chart.js integration
- Date range filtering

### Routes
- `/dashboard/analytics` - main analytics dashboard
- `/dashboard/analytics/products` - product performance
- `/dashboard/analytics/customers` - customer insights
- `/dashboard/analytics/reports` - detailed reports

## 4. Store Following & Notifications (Shomp.Follows)
### Context & Schema
- `Shomp.Follows.Follow` schema (user_id, store_id, created_at)
- `Shomp.Notifications.Notification` schema (user_id, type, title, content, data, read_at, created_at)
- `Shomp.Follows` context (follow_store, unfollow_store, get_followers)
- `Shomp.Notifications` context (create_notification, mark_as_read, get_user_notifications)

### Notification Types
- New product launches
- Store updates/announcements
- Sales and promotions
- Message replies
- Review responses

### Web Layer
- `ShompWeb.FollowLive.Button` (follow/unfollow component)
- `ShompWeb.NotificationLive.Index` (notification center)
- `ShompWeb.StoreLive.Followers` (follower management)
- Real-time notification dropdown

### Routes
- `/notifications` - user notification center
- `/dashboard/followers` - store follower management
- `/dashboard/announcements` - create store announcements

## 5. Wishlist & Collections (Shomp.Wishlists)
### Context & Schema
- `Shomp.Wishlists.Wishlist` schema (user_id, name, description, public, created_at)
- `Shomp.Wishlists.WishlistItem` schema (wishlist_id, product_id, added_at)
- `Shomp.Wishlists` context (create_wishlist, add_to_wishlist, share_wishlist)

### Wishlist Features
- Multiple wishlists per user
- Public/private wishlist sharing
- Price drop notifications
- Share wishlist via link
- Convert wishlist to order

### Web Layer
- `ShompWeb.WishlistLive.Index` (user wishlists)
- `ShompWeb.WishlistLive.Show` (wishlist detail)
- `ShompWeb.WishlistLive.Public` (shared wishlist view)
- Add to wishlist buttons on products

### Routes
- `/wishlists` - user's wishlists
- `/wishlists/:id` - wishlist detail
- `/wishlists/shared/:token` - public wishlist
- `/dashboard/wishlists/analytics` - wishlist analytics for stores

## 6. Store Customization & Themes (Shomp.Themes)
### Context & Schema
- `Shomp.Themes.Theme` schema (name, description, css_variables, layout_options)
- `Shomp.Stores.StoreSettings` schema (store_id, theme_id, custom_css, banner_image, logo)
- `Shomp.Themes` context (apply_theme, customize_store, upload_assets)

### Customization Features
- Pre-built theme selection
- Custom color schemes
- Logo and banner uploads
- Custom CSS injection
- Layout options (grid/list views)
- Font selection

### Web Layer
- `ShompWeb.ThemeLive.Selector` (theme selection interface)
- `ShompWeb.ThemeLive.Customizer` (live theme preview)
- `ShompWeb.StoreLive.Settings` (store appearance settings)
- Live preview functionality

### Routes
- `/dashboard/store/themes` - theme selection
- `/dashboard/store/customize` - store customization
- `/dashboard/store/assets` - manage store assets

## 7. Multi-Store Management (Shomp.Organizations)
### Context & Schema
- `Shomp.Organizations.Organization` schema (name, description, owner_id, created_at)
- `Shomp.Organizations.Membership` schema (organization_id, user_id, role, permissions)
- `Shomp.Organizations` context (create_organization, invite_member, manage_permissions)

### Management Features
- Team member invitations
- Role-based permissions
- Shared analytics dashboard
- Cross-store promotions
- Bulk operations
- Unified messaging inbox

### Web Layer
- `ShompWeb.OrganizationLive.Dashboard` (organization overview)
- `ShompWeb.OrganizationLive.Members` (team management)
- `ShompWeb.OrganizationLive.Stores` (multi-store view)
- Permission-based UI components

### Routes
- `/dashboard/organization` - organization dashboard
- `/dashboard/organization/members` - team management
- `/dashboard/organization/stores` - manage multiple stores
- `/dashboard/organization/settings` - organization settings

## 8. Advanced Product Options (Shomp.ProductVariants)
### Context & Schema
- `Shomp.ProductVariants.Variant` schema (product_id, name, price_modifier, sku, inventory_count)
- `Shomp.ProductVariants.VariantOption` schema (variant_id, option_name, option_value)
- `Shomp.ProductVariants` context (create_variant, manage_inventory, calculate_price)

### Variant Features
- Size/color/style options
- Price modifiers per variant
- Inventory tracking
- Variant-specific images
- Bulk variant creation
- Variant analytics

### Web Layer
- `ShompWeb.ProductLive.VariantManager` (variant configuration)
- `ShompWeb.ProductLive.VariantSelector` (customer selection)
- Dynamic pricing updates
- Inventory status indicators

### Routes
- `/dashboard/products/:id/variants` - manage product variants
- Integrated into existing product creation/edit flows
- Enhanced product display pages