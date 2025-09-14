defmodule Shomp.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Notifications.Notification

  @doc """
  Returns the list of notifications for a user.
  """
  def list_user_notifications(user_id, opts \\ []) do
    limit = opts[:limit] || 50
    unread_only = opts[:unread_only] || false

    query = from n in Notification,
            where: n.user_id == ^user_id,
            order_by: [desc: n.inserted_at]

    query = if unread_only do
      from n in query, where: n.read == false
    else
      query
    end

    query = from n in query, limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets a single notification.
  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Creates a notification.
  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification.
  """
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notification.
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(%Notification{} = notification) do
    update_notification(notification, %{read: true})
  end

  @doc """
  Marks all notifications as read for a user.
  """
  def mark_all_as_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and n.read == false)
    |> Repo.update_all(set: [read: true])
  end

  @doc """
  Gets the count of unread notifications for a user.
  """
  def unread_count(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and n.read == false)
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a notification for order status updates.
  """
  def create_order_notification(user_id, order_id, status, message) do
    create_notification(%{
      user_id: user_id,
      title: "Order Update",
      message: message,
      type: "order_update",
      action_url: "/orders/#{order_id}",
      metadata: %{order_id: order_id, status: status}
    })
  end

  @doc """
  Creates a notification for support ticket updates.
  """
  def create_support_notification(user_id, ticket_id, status, message) do
    create_notification(%{
      user_id: user_id,
      title: "Support Ticket Update",
      message: message,
      type: "support_ticket",
      action_url: "/support/#{ticket_id}",
      metadata: %{ticket_id: ticket_id, status: status}
    })
  end

  @doc """
  Creates a system notification.
  """
  def create_system_notification(user_id, title, message, opts \\ []) do
    create_notification(%{
      user_id: user_id,
      title: title,
      message: message,
      type: "system",
      action_url: opts[:action_url],
      metadata: opts[:metadata] || %{},
      priority: opts[:priority] || "normal"
    })
  end

  # ===== ORDER NOTIFICATIONS =====

  @doc """
  Creates a notification when an order is confirmed.
  """
  def notify_order_confirmed(user_id, order_id, order_amount) do
    create_notification(%{
      user_id: user_id,
      title: "Order Confirmed",
      message: "Your order for $#{order_amount} has been confirmed and payment received.",
      type: "order_update",
      action_url: "/dashboard/purchases",
      metadata: %{order_id: order_id, status: "confirmed"},
      priority: "high"
    })
  end

  @doc """
  Creates a notification when payment is received.
  """
  def notify_payment_received(user_id, order_id, amount) do
    create_notification(%{
      user_id: user_id,
      title: "Payment Received",
      message: "Payment of $#{amount} has been successfully processed.",
      type: "payment_received",
      action_url: "/dashboard/purchases",
      metadata: %{order_id: order_id, amount: amount},
      priority: "high"
    })
  end

  @doc """
  Creates a notification when an order is shipped.
  """
  def notify_order_shipped(user_id, order_id, tracking_number \\ nil) do
    message = if tracking_number do
      "Your order has been shipped! Tracking number: #{tracking_number}"
    else
      "Your order has been shipped!"
    end

    create_notification(%{
      user_id: user_id,
      title: "Order Shipped",
      message: message,
      type: "order_shipped",
      action_url: "/dashboard/purchases",
      metadata: %{order_id: order_id, tracking_number: tracking_number},
      priority: "high"
    })
  end

  @doc """
  Creates a notification when an order is delivered.
  """
  def notify_order_delivered(user_id, order_id) do
    create_notification(%{
      user_id: user_id,
      title: "Order Delivered",
      message: "Your order has been delivered successfully!",
      type: "order_delivered",
      action_url: "/dashboard/purchases",
      metadata: %{order_id: order_id},
      priority: "normal"
    })
  end

  @doc """
  Creates a notification when a refund is processed.
  """
  def notify_refund_processed(user_id, order_id, refund_amount) do
    create_notification(%{
      user_id: user_id,
      title: "Refund Processed",
      message: "Your refund of $#{refund_amount} has been processed and will appear in your account within 5-10 business days.",
      type: "refund_processed",
      action_url: "/dashboard/purchases",
      metadata: %{order_id: order_id, refund_amount: refund_amount},
      priority: "high"
    })
  end

  # ===== SELLER NOTIFICATIONS =====

  @doc """
  Creates a notification when a seller receives a new order.
  """
  def notify_seller_new_order(seller_id, order_id, customer_name, order_amount) do
    create_notification(%{
      user_id: seller_id,
      title: "New Order Received",
      message: "You received a new order from #{customer_name} for $#{order_amount}",
      type: "new_order",
      action_url: "/dashboard/orders",
      metadata: %{order_id: order_id, customer_name: customer_name, amount: order_amount},
      priority: "urgent"
    })
  end

  @doc """
  Creates a notification when store balance is updated.
  """
  def notify_store_balance_update(seller_id, store_id, new_balance) do
    create_notification(%{
      user_id: seller_id,
      title: "Store Balance Updated",
      message: "Your store balance has been updated to $#{new_balance}",
      type: "store_balance_update",
      action_url: "/dashboard/balance",
      metadata: %{store_id: store_id, balance: new_balance},
      priority: "normal"
    })
  end

  @doc """
  Creates a notification when payout is processed.
  """
  def notify_payout_processed(seller_id, payout_amount) do
    create_notification(%{
      user_id: seller_id,
      title: "Payout Processed",
      message: "Your payout of $#{payout_amount} has been processed and sent to your bank account.",
      type: "payout_notification",
      action_url: "/dashboard/balance",
      metadata: %{payout_amount: payout_amount},
      priority: "high"
    })
  end

  # ===== KYC NOTIFICATIONS =====

  @doc """
  Creates a notification when KYC verification is completed.
  """
  def notify_kyc_complete(user_id, status) do
    title = if status == "approved" do
      "KYC Verification Approved"
    else
      "KYC Verification #{String.capitalize(status)}"
    end

    message = if status == "approved" do
      "Your KYC verification has been approved! You can now receive payouts."
    else
      "Your KYC verification has been #{status}. Please check your documents and resubmit if needed."
    end

    create_notification(%{
      user_id: user_id,
      title: title,
      message: message,
      type: "kyc_complete",
      action_url: "/dashboard/kyc",
      metadata: %{status: status},
      priority: "high"
    })
  end

  # ===== PRODUCT NOTIFICATIONS =====

  @doc """
  Creates a notification when a product is added.
  """
  def notify_product_added(seller_id, product_id, product_name) do
    create_notification(%{
      user_id: seller_id,
      title: "Product Added",
      message: "Your product '#{product_name}' has been successfully added to your store.",
      type: "product_added",
      action_url: "/dashboard/products/#{product_id}",
      metadata: %{product_id: product_id, product_name: product_name},
      priority: "normal"
    })
  end

  @doc """
  Creates a notification when a product is approved.
  """
  def notify_product_approved(seller_id, product_id, product_name) do
    create_notification(%{
      user_id: seller_id,
      title: "Product Approved",
      message: "Your product '#{product_name}' has been approved and is now live.",
      type: "product_approved",
      action_url: "/dashboard/products/#{product_id}",
      metadata: %{product_id: product_id, product_name: product_name},
      priority: "normal"
    })
  end

  @doc """
  Creates a notification when a product is flagged for review.
  """
  def notify_product_flagged(seller_id, product_id, product_name, reason) do
    create_notification(%{
      user_id: seller_id,
      title: "Product Flagged for Review",
      message: "Your product '#{product_name}' has been flagged for review. Reason: #{reason}",
      type: "product_flagged",
      action_url: "/dashboard/products/#{product_id}",
      metadata: %{product_id: product_id, product_name: product_name, reason: reason},
      priority: "high"
    })
  end

  # ===== SUPPORT NOTIFICATIONS =====

  @doc """
  Creates a notification when a support ticket is created.
  """
  def notify_support_ticket_created(user_id, ticket_id, subject) do
    create_notification(%{
      user_id: user_id,
      title: "Support Ticket Created",
      message: "Your support ticket '#{subject}' has been created and we'll respond within 24 hours.",
      type: "support_request",
      action_url: "/support/#{ticket_id}",
      metadata: %{ticket_id: ticket_id, subject: subject},
      priority: "normal"
    })
  end

  @doc """
  Creates a notification when a support ticket is updated.
  """
  def notify_support_ticket_updated(user_id, ticket_id, subject, status) do
    create_notification(%{
      user_id: user_id,
      title: "Support Ticket Updated",
      message: "Your support ticket '#{subject}' status has been updated to #{status}.",
      type: "support_request",
      action_url: "/support/#{ticket_id}",
      metadata: %{ticket_id: ticket_id, subject: subject, status: status},
      priority: "normal"
    })
  end

  # ===== FEATURE REQUEST NOTIFICATIONS =====

  @doc """
  Creates a notification when a feature request is submitted.
  """
  def notify_feature_request_submitted(user_id, request_id, title) do
    create_notification(%{
      user_id: user_id,
      title: "Feature Request Submitted",
      message: "Your feature request '#{title}' has been submitted and is under review.",
      type: "feature_request",
      action_url: "/features/#{request_id}",
      metadata: %{request_id: request_id, title: title},
      priority: "low"
    })
  end

  # ===== DONATION NOTIFICATIONS =====

  @doc """
  Creates a notification when a donation is received.
  """
  def notify_donation_received(user_id, amount, donor_name \\ "Anonymous") do
    create_notification(%{
      user_id: user_id,
      title: "Donation Received",
      message: "Thank you! #{donor_name} donated $#{amount} to support the platform.",
      type: "donation",
      action_url: "/dashboard/donations",
      metadata: %{amount: amount, donor_name: donor_name},
      priority: "normal"
    })
  end

  # ===== SYSTEM NOTIFICATIONS =====

  @doc """
  Creates a notification for system maintenance.
  """
  def notify_system_maintenance(user_id, message, start_time, end_time) do
    create_notification(%{
      user_id: user_id,
      title: "Scheduled Maintenance",
      message: "#{message} Scheduled from #{start_time} to #{end_time}.",
      type: "system_maintenance",
      action_url: "/status",
      metadata: %{start_time: start_time, end_time: end_time},
      priority: "high"
    })
  end

  @doc """
  Creates a notification for security alerts.
  """
  def notify_security_alert(user_id, message) do
    create_notification(%{
      user_id: user_id,
      title: "Security Alert",
      message: message,
      type: "security_alert",
      action_url: "/security",
      metadata: %{},
      priority: "urgent"
    })
  end

  # ===== BULK NOTIFICATIONS =====

  @doc """
  Creates notifications for multiple users.
  """
  def create_bulk_notifications(user_ids, notification_data) do
    notifications = Enum.map(user_ids, fn user_id ->
      %{
        user_id: user_id,
        title: notification_data.title,
        message: notification_data.message,
        type: notification_data.type,
        action_url: notification_data.action_url,
        metadata: notification_data.metadata || %{},
        priority: notification_data.priority || "normal",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)

    Repo.insert_all(Notification, notifications)
  end

  @doc """
  Gets notifications by type for a user.
  """
  def get_user_notifications_by_type(user_id, type, opts \\ []) do
    limit = opts[:limit] || 50
    unread_only = opts[:unread_only] || false

    query = from n in Notification,
            where: n.user_id == ^user_id and n.type == ^type,
            order_by: [desc: n.inserted_at]

    query = if unread_only do
      from n in query, where: n.read == false
    else
      query
    end

    query = from n in query, limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets notification by immutable_id.
  """
  def get_notification_by_immutable_id(immutable_id) do
    Repo.get_by(Notification, immutable_id: immutable_id)
  end

  @doc """
  Marks a notification as read by immutable_id.
  """
  def mark_as_read_by_immutable_id(immutable_id) do
    case get_notification_by_immutable_id(immutable_id) do
      nil -> {:error, :not_found}
      notification -> mark_as_read(notification)
    end
  end
end
