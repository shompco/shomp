# Shomp MVP Core 18 - Purchase Activity Toaster Notifications

## Overview
Add toaster popup notifications that display recent purchase activity to create social proof and show platform activity. These notifications will cycle through the last 5-10 purchases with relative timestamps.

## Core Features

### 1. Purchase Activity Toasters
- **Recent Purchase Display**: Show last 5-10 purchases in rotating toaster notifications
- **Relative Timestamps**: Display "4h ago", "1min ago", "2 days ago" etc.
- **Purchase Details**: Show product name, buyer location (city/state), and amount
- **Privacy-Focused**: Only show buyer initials and general location
- **Auto-Rotation**: Cycle through recent purchases automatically
- **Dismissible**: Users can close individual toasters

### 2. Real-Time Updates
- **Live Purchase Detection**: New purchases trigger immediate toaster display
- **WebSocket Integration**: Real-time updates via LiveView
- **Queue Management**: Handle multiple simultaneous purchases gracefully
- **Performance Optimized**: Efficient data loading and display

### 3. Privacy & Security
- **Anonymized Data**: Only show buyer initials, not full names
- **Location Privacy**: Show city/state only, not full addresses
- **Opt-Out Support**: Buyers can opt out of public display
- **Data Retention**: Only show recent purchases (last 24-48 hours)

## Database Schema

### Purchase Activity Table
```elixir
create table(:purchase_activities) do
  add :id, :bigserial, primary_key: true
  add :order_id, references(:universal_orders, type: :string), null: false
  add :product_id, references(:products, type: :string), null: false
  add :buyer_id, references(:users, type: :bigserial), null: false
  add :buyer_initials, :string, null: false
  add :buyer_location, :string, null: true # "San Francisco, CA"
  add :product_title, :string, null: false
  add :amount, :decimal, precision: 10, scale: 2, null: false
  add :is_public, :boolean, default: true
  add :displayed_at, :utc_datetime, null: true
  add :display_count, :integer, default: 0
  
  timestamps()
end

create index(:purchase_activities, [:inserted_at])
create index(:purchase_activities, [:is_public])
create index(:purchase_activities, [:displayed_at])
create index(:purchase_activities, [:order_id])
```

## Implementation

### 1. Purchase Activity Context
```elixir
defmodule Shomp.PurchaseActivities do
  @moduledoc """
  Handles purchase activity tracking and display.
  """

  alias Shomp.PurchaseActivities.PurchaseActivity
  alias Shomp.Repo

  @doc """
  Records a new purchase activity.
  """
  def record_purchase(order, product, buyer) do
    # Only record if buyer hasn't opted out
    if buyer.show_purchase_activity != false do
      activity_attrs = %{
        order_id: order.id,
        product_id: product.id,
        buyer_id: buyer.id,
        buyer_initials: get_buyer_initials(buyer),
        buyer_location: get_buyer_location(buyer),
        product_title: product.title,
        amount: order.total_amount,
        is_public: buyer.show_purchase_activity != false
      }

      %PurchaseActivity{}
      |> PurchaseActivity.changeset(activity_attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Gets recent public purchase activities for toaster display.
  """
  def get_recent_activities(limit \\ 10) do
    from(pa in PurchaseActivity,
      where: pa.is_public == true,
      order_by: [desc: pa.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets activities that haven't been displayed yet.
  """
  def get_unshown_activities(limit \\ 5) do
    from(pa in PurchaseActivity,
      where: pa.is_public == true and is_nil(pa.displayed_at),
      order_by: [asc: pa.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Marks an activity as displayed.
  """
  def mark_as_displayed(activity) do
    activity
    |> PurchaseActivity.changeset(%{
      displayed_at: DateTime.utc_now(),
      display_count: activity.display_count + 1
    })
    |> Repo.update()
  end

  @doc """
  Cleans up old activities (older than 48 hours).
  """
  def cleanup_old_activities do
    cutoff_time = DateTime.add(DateTime.utc_now(), -48, :hour)
    
    from(pa in PurchaseActivity,
      where: pa.inserted_at < ^cutoff_time
    )
    |> Repo.delete_all()
  end

  defp get_buyer_initials(buyer) do
    if buyer.name do
      buyer.name
      |> String.split()
      |> Enum.map(&String.first/1)
      |> Enum.join("")
      |> String.upcase()
    else
      String.first(buyer.email) |> String.upcase()
    end
  end

  defp get_buyer_location(buyer) do
    # This would come from user profile or order shipping address
    # For now, return a placeholder or get from user's location setting
    buyer.location || "Unknown Location"
  end
end
```

### 2. Toaster Component
```elixir
defmodule ShompWeb.Components.PurchaseToaster do
  use ShompWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="fixed top-4 right-4 z-50 space-y-2" id="purchase-toasters">
      <%= for {activity, index} <- Enum.with_index(@activities) do %>
        <div 
          class={[
            "toast toast-top toast-end transform transition-all duration-300",
            if(@show_toaster, do: "translate-x-0 opacity-100", else: "translate-x-full opacity-0")
          ]}
          style={"animation-delay: #{index * 200}ms"}
        >
          <div class="alert alert-info shadow-lg">
            <div class="flex items-center space-x-3">
              <!-- Avatar -->
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content rounded-full w-8">
                  <span class="text-xs font-bold"><%= activity.buyer_initials %></span>
                </div>
              </div>
              
              <!-- Purchase Info -->
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-base-content">
                  Just purchased <span class="font-semibold"><%= activity.product_title %></span>
                </p>
                <p class="text-xs text-base-content/70">
                  <%= activity.buyer_location %> • <%= format_time_ago(activity.inserted_at) %>
                </p>
              </div>
              
              <!-- Amount -->
              <div class="text-right">
                <p class="text-sm font-bold text-primary">$<%= format_amount(activity.amount) %></p>
              </div>
              
              <!-- Close Button -->
              <button
                class="btn btn-ghost btn-xs"
                phx-click="dismiss_toaster"
                phx-value-activity_id={activity.id}
                phx-target={@myself}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    activities = Shomp.PurchaseActivities.get_recent_activities(5)
    {:ok, assign(socket, 
      activities: activities,
      show_toaster: false,
      current_index: 0
    )}
  end

  def handle_event("dismiss_toaster", %{"activity_id" => activity_id}, socket) do
    activity = Enum.find(socket.assigns.activities, &(&1.id == String.to_integer(activity_id)))
    if activity do
      Shomp.PurchaseActivities.mark_as_displayed(activity)
    end
    
    # Remove from display
    updated_activities = Enum.reject(socket.assigns.activities, &(&1.id == String.to_integer(activity_id)))
    {:noreply, assign(socket, activities: updated_activities)}
  end

  def handle_info(:show_toaster, socket) do
    {:noreply, assign(socket, show_toaster: true)}
  end

  def handle_info(:hide_toaster, socket) do
    {:noreply, assign(socket, show_toaster: false)}
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)
    
    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> "#{div(diff_seconds, 604800)}w ago"
    end
  end

  defp format_amount(amount) do
    :erlang.float_to_binary(amount, decimals: 0)
  end
end
```

### 3. Toaster Manager LiveView
```elixir
defmodule ShompWeb.PurchaseToasterLive do
  use ShompWeb, :live_view

  alias Shomp.PurchaseActivities

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Start the toaster rotation process
      Process.send_after(self(), :check_new_activities, 5000)
    end
    
    {:ok, assign(socket, 
      activities: [],
      current_index: 0,
      rotation_interval: 8000 # 8 seconds per toaster
    )}
  end

  def handle_info(:check_new_activities, socket) do
    # Get new activities that haven't been shown
    new_activities = PurchaseActivities.get_unshown_activities(3)
    
    if not Enum.empty?(new_activities) do
      # Add new activities to the rotation
      updated_activities = socket.assigns.activities ++ new_activities
      |> Enum.take(10) # Keep only last 10
      
      # Start showing toasters
      send(self(), :show_next_toaster)
      
      {:noreply, assign(socket, activities: updated_activities)}
    else
      # Check again in 10 seconds
      Process.send_after(self(), :check_new_activities, 10000)
      {:noreply, socket}
    end
  end

  def handle_info(:show_next_toaster, socket) do
    if socket.assigns.current_index < length(socket.assigns.activities) do
      # Show current toaster
      send(self(), {:show_toaster, socket.assigns.current_index})
      
      # Schedule next toaster
      Process.send_after(self(), :show_next_toaster, socket.assigns.rotation_interval)
      
      {:noreply, assign(socket, current_index: socket.assigns.current_index + 1)}
    else
      # Reset rotation
      Process.send_after(self(), :check_new_activities, 5000)
      {:noreply, assign(socket, current_index: 0)}
    end
  end

  def handle_info({:show_toaster, index}, socket) do
    activity = Enum.at(socket.assigns.activities, index)
    if activity do
      # Mark as displayed
      PurchaseActivities.mark_as_displayed(activity)
      
      # Send to toaster component
      send(self(), :show_toaster)
    end
    
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <ShompWeb.Components.PurchaseToaster 
        id="purchase-toaster"
        activities={@activities}
        current_index={@current_index}
      />
    </div>
    """
  end
end
```

### 4. Order Integration
```elixir
# In your existing order processing code
defmodule Shomp.Orders do
  # ... existing code ...

  @doc """
  Processes a completed order and records purchase activity.
  """
  def process_completed_order(order) do
    with {:ok, order} <- mark_order_as_completed(order),
         :ok <- record_purchase_activity(order) do
      {:ok, order}
    end
  end

  defp record_purchase_activity(order) do
    # Get order items and record activity for each
    order_items = Repo.preload(order, :order_items).order_items
    
    for item <- order_items do
      product = Repo.preload(item, :product).product
      buyer = Repo.preload(order, :user).user
      
      Shomp.PurchaseActivities.record_purchase(order, product, buyer)
    end
    
    :ok
  end
end
```

### 5. Layout Integration
```elixir
# In your root layout
defmodule ShompWeb.Layouts.Root do
  use ShompWeb, :html

  def html(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full">
      <head>
        <!-- ... existing head content ... -->
      </head>
      <body class="h-full bg-base-200">
        <!-- ... existing body content ... -->
        
        <!-- Purchase Toaster -->
        <div id="purchase-toaster-container" phx-hook="PurchaseToaster" data-page={@page}>
          <!-- Toaster will be rendered here -->
        </div>
      </body>
    </html>
    """
  end
end
```

### 6. JavaScript Hook
```javascript
// In assets/js/app.js
let Hooks = {};

Hooks.PurchaseToaster = {
  mounted() {
    // This hook can handle any client-side toaster behavior
    // The main logic is handled server-side via LiveView
  }
};

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});
```

### 7. User Privacy Settings
```elixir
# Add to user schema
defmodule Shomp.Accounts.User do
  # ... existing fields ...
  field :show_purchase_activity, :boolean, default: true
end

# Add to user profile edit form
defmodule ShompWeb.ProfileLive.Edit do
  # ... existing code ...

  def render(assigns) do
    ~H"""
    <!-- ... existing form fields ... -->
    
    <div class="form-control">
      <label class="label cursor-pointer">
        <input 
          type="checkbox" 
          name="show_purchase_activity" 
          class="checkbox" 
          checked={@form[:show_purchase_activity].value}
        />
        <span class="label-text">Show my purchases in activity feed</span>
      </label>
      <label class="label">
        <span class="label-text-alt">
          When enabled, your purchases will appear as anonymous activity notifications to other users
        </span>
      </label>
    </div>
    """
  end
end
```

## Routes
```elixir
# In router.ex - no additional routes needed
# The toaster is integrated into the main layout
```

## Benefits

### For Platform
- **Social Proof**: Shows active community and recent purchases
- **Engagement**: Creates FOMO and encourages purchases
- **Activity Feel**: Platform feels alive and active
- **Trust Building**: Real purchase activity builds credibility

### For Users
- **Community Feel**: See other users actively purchasing
- **Product Discovery**: Learn about popular products
- **Privacy Control**: Can opt out of public display
- **Non-Intrusive**: Dismissible toasters that don't interfere

### For Sellers
- **Social Proof**: Their products get public visibility
- **Sales Encouragement**: Seeing others buy encourages more sales
- **Market Validation**: Shows demand for their products

## Implementation Notes

### Performance Considerations
- **Efficient Queries**: Only load recent activities
- **Cleanup Process**: Regular cleanup of old activities
- **Rate Limiting**: Don't overwhelm users with too many toasters
- **Caching**: Cache recent activities for better performance

### Privacy Features
- **Anonymized Data**: Only show initials and general location
- **Opt-Out Support**: Users can disable public display
- **Data Retention**: Only keep recent activities (48 hours)
- **Secure Display**: No sensitive information exposed

This toaster system creates a vibrant, active feel for the platform while respecting user privacy and providing social proof for purchases.
