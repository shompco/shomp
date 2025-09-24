defmodule Shomp.NotificationServices do
  @moduledoc """
  The NotificationServices context for handling external notification services.
  """

  alias Shomp.NotificationPreferences
  alias Shomp.Accounts

  @doc """
  Sends an email notification via Brevo if the user has enabled email notifications for this type.
  """
  def send_email_notification(user_id, notification_type, subject, message, opts \\ []) do
    if NotificationPreferences.wants_email_notification?(user_id, notification_type) do
      user = Accounts.get_user!(user_id)
      Shomp.BrevoService.send_email(user.email, subject, message, opts)
    else
      {:ok, :skipped}
    end
  end

  @doc """
  Sends an SMS notification via MessageBird if the user has enabled SMS notifications for this type.
  """
  def send_sms_notification(user_id, notification_type, message, opts \\ []) do
    if NotificationPreferences.wants_sms_notification?(user_id, notification_type) do
      user = Accounts.get_user!(user_id)

      if user.phone_number && user.phone_number != "" do
        Shomp.MessageBirdService.send_sms(user.phone_number, message, opts)
      else
        {:ok, :skipped_no_phone}
      end
    else
      {:ok, :skipped}
    end
  end

  @doc """
  Sends both email and SMS notifications based on user preferences.
  """
  def send_notification(user_id, notification_type, subject, message, opts \\ []) do
    email_result = send_email_notification(user_id, notification_type, subject, message, opts)
    sms_result = send_sms_notification(user_id, notification_type, message, opts)

    {email_result, sms_result}
  end

  @doc """
  Convenience function for "You Sold Something" notifications.
  """
  def notify_sale(user_id, product_name, buyer_name, amount) do
    subject = "🎉 You sold #{product_name}!"
    message = """
    Congratulations! #{buyer_name} just purchased "#{product_name}" for $#{amount}.

    You can view the order details in your seller dashboard.
    """

    send_notification(user_id, :you_sold_something, subject, message)
  end

  @doc """
  Convenience function for shipping label created notifications.
  """
  def notify_shipping_label_created(user_id, product_name, tracking_number) do
    subject = "📦 Shipping label created for #{product_name}"
    message = """
    A shipping label has been created for your purchase of "#{product_name}".

    Tracking number: #{tracking_number}

    You can track your package using the tracking number above.
    """

    send_notification(user_id, :shipping_label_created, subject, message)
  end

  @doc """
  Convenience function for purchase shipped notifications.
  """
  def notify_purchase_shipped(user_id, product_name, tracking_number) do
    subject = "🚚 Your #{product_name} has been shipped!"
    message = """
    Great news! Your purchase of "#{product_name}" has been shipped.

    Tracking number: #{tracking_number}

    You can track your package using the tracking number above.
    """

    send_notification(user_id, :purchase_shipped, subject, message)
  end

  @doc """
  Convenience function for purchase delivered notifications.
  """
  def notify_purchase_delivered(user_id, product_name) do
    subject = "✅ Your #{product_name} has been delivered!"
    message = """
    Your purchase of "#{product_name}" has been delivered successfully.

    We hope you enjoy your purchase! Don't forget to leave a review.
    """

    send_notification(user_id, :purchase_delivered, subject, message)
  end

  @doc """
  Convenience function for review reminder notifications.
  """
  def notify_review_reminder(user_id, product_name, seller_name) do
    subject = "⭐ Please leave a review for #{product_name}"
    message = """
    Hi there! We hope you're enjoying your purchase of "#{product_name}" from #{seller_name}.

    Your review helps other buyers make informed decisions and helps sellers improve their products.

    Please take a moment to leave a review when you're ready.
    """

    send_notification(user_id, :leave_review_reminder, subject, message)
  end

  @doc """
  Convenience function for purchase shipped notifications (simplified version for webhooks).
  """
  def notify_purchase_shipped(user_id, subject, message) do
    send_notification(user_id, :purchase_shipped, subject, message)
  end

  @doc """
  Convenience function for purchase delivered notifications (simplified version for webhooks).
  """
  def notify_purchase_delivered(user_id, subject, message) do
    send_notification(user_id, :purchase_delivered, subject, message)
  end
end
