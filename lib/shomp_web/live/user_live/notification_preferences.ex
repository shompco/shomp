defmodule ShompWeb.UserLive.NotificationPreferences do
  use ShompWeb, :live_view

  alias Shomp.EmailPreferences

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    preferences = EmailPreferences.get_user_preferences(user.id)
    
    socket = 
      socket
      |> assign(:preferences, preferences)
      |> assign(:page_title, "Notification Preferences")

    {:ok, socket}
  end

  def handle_event("update_preferences", %{"preferences" => pref_params}, socket) do
    user = socket.assigns.current_scope.user
    
    case EmailPreferences.update_preferences(user.id, pref_params) do
      {:ok, updated_preferences} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Notification preferences updated successfully")
         |> assign(:preferences, updated_preferences)}
      
      {:error, changeset} ->
        {:noreply, assign(socket, :preferences_changeset, changeset)}
    end
  end

  def handle_event("reset_to_defaults", _params, socket) do
    user = socket.assigns.current_scope.user
    
    default_prefs = %{
      order_confirmation: true,
      order_status_updates: true,
      shipping_notifications: true,
      delivery_confirmation: true,
      support_ticket_updates: true,
      support_ticket_resolved: true,
      product_updates: false,
      promotional_emails: false,
      newsletter: false,
      security_alerts: true,
      account_updates: true,
      system_maintenance: true
    }
    
    case EmailPreferences.update_preferences(user.id, default_prefs) do
      {:ok, updated_preferences} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Notification preferences reset to defaults")
         |> assign(:preferences, updated_preferences)}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reset preferences")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">Notification Preferences</h1>
        <a href={~p"/dashboard"} class="btn btn-ghost">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
          </svg>
          Back to Dashboard
        </a>
      </div>

      <div class="max-w-4xl">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title mb-6">Manage your notification preferences</h2>
            <p class="text-sm text-gray-600 mb-6">
              Choose which notifications you'd like to receive. You can always change these settings later.
            </p>
            
            <.form 
              for={@preferences} 
              phx-submit="update_preferences"
              class="space-y-8"
            >
              <!-- Order Notifications -->
              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-primary">Order Notifications</h3>
                <p class="text-sm text-gray-600">Stay updated on your order status and delivery information.</p>
                
                <div class="space-y-3">
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Order confirmations</span>
                      <p class="text-xs text-gray-500">Get notified when your order is confirmed</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[order_confirmation]"
                      class="toggle toggle-primary"
                      checked={@preferences.order_confirmation}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Order status updates</span>
                      <p class="text-xs text-gray-500">Get notified when your order status changes</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[order_status_updates]"
                      class="toggle toggle-primary"
                      checked={@preferences.order_status_updates}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Shipping notifications</span>
                      <p class="text-xs text-gray-500">Get notified when your order ships</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[shipping_notifications]"
                      class="toggle toggle-primary"
                      checked={@preferences.shipping_notifications}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Delivery confirmations</span>
                      <p class="text-xs text-gray-500">Get notified when your order is delivered</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[delivery_confirmation]"
                      class="toggle toggle-primary"
                      checked={@preferences.delivery_confirmation}
                    />
                  </label>
                </div>
              </div>

              <!-- Support Notifications -->
              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-primary">Support Notifications</h3>
                <p class="text-sm text-gray-600">Get notified about your support ticket updates.</p>
                
                <div class="space-y-3">
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Support ticket updates</span>
                      <p class="text-xs text-gray-500">Get notified when there are updates to your support tickets</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[support_ticket_updates]"
                      class="toggle toggle-primary"
                      checked={@preferences.support_ticket_updates}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Support ticket resolved</span>
                      <p class="text-xs text-gray-500">Get notified when your support tickets are resolved</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[support_ticket_resolved]"
                      class="toggle toggle-primary"
                      checked={@preferences.support_ticket_resolved}
                    />
                  </label>
                </div>
              </div>

              <!-- Marketing Notifications -->
              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-primary">Marketing & Updates</h3>
                <p class="text-sm text-gray-600">Optional promotional and product update notifications.</p>
                
                <div class="space-y-3">
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Product updates</span>
                      <p class="text-xs text-gray-500">Get notified about new products and updates</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[product_updates]"
                      class="toggle toggle-primary"
                      checked={@preferences.product_updates}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Promotional emails</span>
                      <p class="text-xs text-gray-500">Get notified about special offers and promotions</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[promotional_emails]"
                      class="toggle toggle-primary"
                      checked={@preferences.promotional_emails}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Newsletter</span>
                      <p class="text-xs text-gray-500">Get our regular newsletter with updates and tips</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[newsletter]"
                      class="toggle toggle-primary"
                      checked={@preferences.newsletter}
                    />
                  </label>
                </div>
              </div>

              <!-- System Notifications -->
              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-primary">System Notifications</h3>
                <p class="text-sm text-gray-600">Important system and security notifications (recommended to keep enabled).</p>
                
                <div class="space-y-3">
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Security alerts</span>
                      <p class="text-xs text-gray-500">Get notified about important security updates</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[security_alerts]"
                      class="toggle toggle-primary"
                      checked={@preferences.security_alerts}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">Account updates</span>
                      <p class="text-xs text-gray-500">Get notified about changes to your account</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[account_updates]"
                      class="toggle toggle-primary"
                      checked={@preferences.account_updates}
                    />
                  </label>
                  
                  <label class="flex items-center justify-between cursor-pointer">
                    <div>
                      <span class="text-sm font-medium">System maintenance</span>
                      <p class="text-xs text-gray-500">Get notified about scheduled maintenance</p>
                    </div>
                    <input 
                      type="checkbox" 
                      name="preferences[system_maintenance]"
                      class="toggle toggle-primary"
                      checked={@preferences.system_maintenance}
                    />
                  </label>
                </div>
              </div>

              <!-- Action Buttons -->
              <div class="divider"></div>
              
              <div class="flex justify-between items-center">
                <button 
                  type="button" 
                  phx-click="reset_to_defaults"
                  class="btn btn-ghost"
                >
                  Reset to Defaults
                </button>
                
                <div class="flex gap-2">
                  <a href={~p"/dashboard"} class="btn btn-ghost">
                    Cancel
                  </a>
                  <button type="submit" class="btn btn-primary">
                    Save Preferences
                  </button>
                </div>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
