defmodule ShompWeb.PurchaseToasterLive do
  use ShompWeb, :live_component

  @impl true
  def mount(socket) do
    # Subscribe to purchase activities
    Phoenix.PubSub.subscribe(Shomp.PubSub, "purchase_activities")

    # Get recent activities for initial display
    recent_activities = Shomp.PurchaseActivities.get_recent_activities(3)

    {:ok, assign(socket, activities: recent_activities)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed bottom-4 left-4 z-50 space-y-2">
      <%= for activity <- @activities do %>
        <div class="toast toast-bottom toast-start animate-slide-up mb-2">
          <div class="alert alert-info shadow-lg">
            <div class="flex items-center space-x-3">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content rounded-full w-8">
                  <span class="text-xs font-bold"><%= activity.buyer_initials %></span>
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-base-content">
                  Just purchased <span class="font-semibold"><%= activity.product_title %></span>
                </p>
                <p class="text-xs text-base-content/70">
                  <%= activity.buyer_location %> • <%= format_time_ago(activity.inserted_at) %>
                </p>
              </div>
              <div class="text-right">
                <p class="text-sm font-bold text-primary">$<%= format_amount(activity.amount) %></p>
              </div>
              <button class="btn btn-ghost btn-xs" phx-click="remove_toaster" phx-value-id={activity.id}>
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

  @impl true
  def handle_event("remove_toaster", %{"id" => id}, socket) do
    # Remove the toaster from the list
    filtered_activities = Enum.reject(socket.assigns.activities, &(&1.id == id))
    {:noreply, assign(socket, :activities, filtered_activities)}
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    # Convert NaiveDateTime to DateTime if needed
    dt = case datetime do
      %DateTime{} -> datetime
      %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
    end
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 ->
        minutes = div(diff_seconds, 60)
        "#{minutes} minute#{if minutes == 1, do: "", else: "s"} ago"
      diff_seconds < 86400 ->
        hours = div(diff_seconds, 3600)
        "#{hours} hour#{if hours == 1, do: "", else: "s"} ago"
      diff_seconds < 604800 ->
        days = div(diff_seconds, 86400)
        "#{days} day#{if days == 1, do: "", else: "s"} ago"
      true ->
        weeks = div(diff_seconds, 604800)
        "#{weeks} week#{if weeks == 1, do: "", else: "s"} ago"
    end
  end

  defp format_amount(amount) do
    amount
    |> Decimal.to_float()
    |> Float.round(0)
    |> trunc()
  end
end
