defmodule ShompWeb.NotificationPreferencesLive.Show do
  use ShompWeb, :live_view

  alias Shomp.NotificationPreferences

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    {:ok, preferences} = NotificationPreferences.get_user_preferences(user.id)

    socket =
      socket
      |> assign(:preferences, preferences)
      |> assign(:changeset, NotificationPreferences.change_notification_preference(preferences))

    {:ok, socket}
  end

  @impl true
  def handle_event("update_preferences", %{"notification_preference" => preference_params}, socket) do
    preferences = socket.assigns.preferences

    case NotificationPreferences.update_notification_preference(preferences, preference_params) do
      {:ok, updated_preferences} ->
        socket =
          socket
          |> assign(:preferences, updated_preferences)
          |> assign(:changeset, NotificationPreferences.change_notification_preference(updated_preferences))
          |> put_flash(:info, "Notification preferences updated successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        socket = assign(socket, :changeset, changeset)
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 max-w-4xl">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-base-content mb-2">Notification Preferences</h1>
        <p class="text-base-content/70">
          Choose how you want to be notified about important events. You can receive notifications via email and SMS.
        </p>
      </div>

      <.form for={@changeset} phx-submit="update_preferences" class="space-y-8">
        <div class="bg-base-100 rounded-lg border border-base-300 p-6">
          <h2 class="text-xl font-semibold mb-6 text-base-content">Purchase & Order Notifications</h2>

          <div class="space-y-6">
            <!-- You Sold Something -->
            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div class="flex-1">
                <h3 class="font-medium text-base-content">You Sold Something</h3>
                <p class="text-sm text-base-content/70">Get notified when someone purchases your product</p>
              </div>
              <div class="flex gap-4">
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[email_you_sold_something]"
                    value="true"
                    checked={@preferences.email_you_sold_something}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">Email</span>
                </label>
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[sms_you_sold_something]"
                    value="true"
                    checked={@preferences.sms_you_sold_something}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">SMS</span>
                </label>
              </div>
            </div>

            <!-- Shipping Label Created -->
            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div class="flex-1">
                <h3 class="font-medium text-base-content">Your Purchase's Shipping Label Got Created</h3>
                <p class="text-sm text-base-content/70">Get notified when a shipping label is created for your purchase</p>
              </div>
              <div class="flex gap-4">
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[email_shipping_label_created]"
                    value="true"
                    checked={@preferences.email_shipping_label_created}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">Email</span>
                </label>
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[sms_shipping_label_created]"
                    value="true"
                    checked={@preferences.sms_shipping_label_created}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">SMS</span>
                </label>
              </div>
            </div>

            <!-- Purchase Shipped -->
            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div class="flex-1">
                <h3 class="font-medium text-base-content">Your Purchase Got Shipped</h3>
                <p class="text-sm text-base-content/70">Get notified when your purchase is shipped</p>
              </div>
              <div class="flex gap-4">
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[email_purchase_shipped]"
                    value="true"
                    checked={@preferences.email_purchase_shipped}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">Email</span>
                </label>
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[sms_purchase_shipped]"
                    value="true"
                    checked={@preferences.sms_purchase_shipped}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">SMS</span>
                </label>
              </div>
            </div>

            <!-- Purchase Delivered -->
            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div class="flex-1">
                <h3 class="font-medium text-base-content">Your Purchase Got Delivered</h3>
                <p class="text-sm text-base-content/70">Get notified when your purchase is delivered</p>
              </div>
              <div class="flex gap-4">
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[email_purchase_delivered]"
                    value="true"
                    checked={@preferences.email_purchase_delivered}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">Email</span>
                </label>
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[sms_purchase_delivered]"
                    value="true"
                    checked={@preferences.sms_purchase_delivered}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">SMS</span>
                </label>
              </div>
            </div>

            <!-- Leave Review Reminder -->
            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div class="flex-1">
                <h3 class="font-medium text-base-content">Leave a Review Reminder</h3>
                <p class="text-sm text-base-content/70">Get reminded to leave a review for your purchase</p>
              </div>
              <div class="flex gap-4">
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[email_leave_review_reminder]"
                    value="true"
                    checked={@preferences.email_leave_review_reminder}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">Email</span>
                </label>
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="notification_preference[sms_leave_review_reminder]"
                    value="true"
                    checked={@preferences.sms_leave_review_reminder}
                    class="checkbox checkbox-primary"
                  />
                  <span class="text-sm">SMS</span>
                </label>
              </div>
            </div>
          </div>
        </div>

        <div class="flex justify-end">
          <button type="submit" class="btn btn-primary">
            Save Preferences
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
