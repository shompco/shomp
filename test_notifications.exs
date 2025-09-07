# Test script to create sample notifications
# Run with: elixir test_notifications.exs

# Add the project to the path
Code.prepend_path("_build/dev/lib/shomp/ebin")

# Start the application
Application.ensure_all_started(:shomp)

# Get a user (assuming user with ID 1 exists)
user_id = 1

# Create some sample notifications
notifications = [
  %{
    user_id: user_id,
    title: "Order Status Update",
    message: "Your order #12345 has been shipped and is on its way!",
    type: "order_update",
    read: false,
    action_url: "/orders/12345"
  },
  %{
    user_id: user_id,
    title: "Support Ticket Update",
    message: "Your support ticket has been resolved. Please check your email for details.",
    type: "support_ticket",
    read: false,
    action_url: "/support/tickets/456"
  },
  %{
    user_id: user_id,
    title: "Welcome to Shomp!",
    message: "Thanks for joining our marketplace. Start by creating your first store!",
    type: "system_alert",
    read: true,
    action_url: "/stores/new"
  },
  %{
    user_id: user_id,
    title: "New Product Review",
    message: "Someone left a 5-star review on your product 'Amazing Widget'!",
    type: "product_review",
    read: false,
    action_url: "/products/789"
  },
  %{
    user_id: user_id,
    title: "Payment Received",
    message: "You received a payment of $25.00 for your product sale.",
    type: "payment_received",
    read: false,
    action_url: "/dashboard/balance"
  }
]

# Create the notifications
Enum.each(notifications, fn attrs ->
  case Shomp.Notifications.create_notification(attrs) do
    {:ok, notification} ->
      IO.puts("✅ Created notification: #{notification.title}")
    {:error, changeset} ->
      IO.puts("❌ Failed to create notification: #{inspect(changeset.errors)}")
  end
end)

# Check unread count
unread_count = Shomp.Notifications.unread_count(user_id)
IO.puts("\n📊 Unread notifications: #{unread_count}")

# List recent notifications
recent = Shomp.Notifications.list_user_notifications(user_id, limit: 5)
IO.puts("\n📋 Recent notifications:")
Enum.each(recent, fn notification ->
  status = if notification.read, do: "✅ Read", else: "🔔 Unread"
  IO.puts("  #{status} - #{notification.title}")
end)

IO.puts("\n🎉 Test notifications created! Click the notification bell to see them.")
