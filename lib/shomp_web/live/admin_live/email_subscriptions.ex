defmodule ShompWeb.AdminLive.EmailSubscriptions do
  use ShompWeb, :live_view
  alias Shomp.EmailSubscriptions
  alias Shomp.EmailSubscriptions.EmailSubscription

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.user.role == "admin" do
      {:ok, 
       socket 
       |> assign(:page_title, "Email Subscriptions - Admin")
       |> assign(:page, 1)
       |> assign(:per_page, 50)
       |> assign(:search_query, "")
       |> assign(:status_filter, "all")
       |> assign(:source_filter, "all")
       |> load_subscriptions()}
    else
      {:ok, 
       socket 
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, 
     socket 
     |> assign(:search_query, query)
     |> assign(:page, 1)
     |> load_subscriptions()}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, 
     socket 
     |> assign(:status_filter, status)
     |> assign(:page, 1)
     |> load_subscriptions()}
  end

  def handle_event("filter_source", %{"source" => source}, socket) do
    {:noreply, 
     socket 
     |> assign(:source_filter, source)
     |> assign(:page, 1)
     |> load_subscriptions()}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, 
     socket 
     |> assign(:page, String.to_integer(page))
     |> load_subscriptions()}
  end

  def handle_event("unsubscribe", %{"id" => id}, socket) do
    subscription = EmailSubscriptions.get_email_subscription!(id)
    
    case EmailSubscriptions.unsubscribe_email_subscription(subscription) do
      {:ok, _updated_subscription} ->
        {:noreply, 
         socket 
         |> put_flash(:info, "Email subscription unsubscribed successfully.")
         |> load_subscriptions()}
      
      {:error, _changeset} ->
        {:noreply, 
         socket 
         |> put_flash(:error, "Failed to unsubscribe email subscription.")
         |> load_subscriptions()}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    subscription = EmailSubscriptions.get_email_subscription!(id)
    
    case EmailSubscriptions.delete_email_subscription(subscription) do
      {:ok, _deleted_subscription} ->
        {:noreply, 
         socket 
         |> put_flash(:info, "Email subscription deleted successfully.")
         |> load_subscriptions()}
      
      {:error, _changeset} ->
        {:noreply, 
         socket 
         |> put_flash(:error, "Failed to delete email subscription.")
         |> load_subscriptions()}
    end
  end

  def handle_event("export_csv", _params, socket) do
    subscriptions = get_filtered_subscriptions(socket.assigns)
    csv_data = generate_csv(subscriptions)
    
    {:noreply, 
     socket 
     |> put_flash(:info, "CSV export ready. Check your downloads folder.")
     |> push_event("download_csv", %{data: csv_data, filename: "email_subscriptions_#{Date.utc_today()}.csv"})}
  end

  defp load_subscriptions(socket) do
    subscriptions = get_filtered_subscriptions(socket.assigns)
    total_count = length(subscriptions)
    total_pages = ceil(total_count / socket.assigns.per_page)
    
    socket
    |> assign(:subscriptions, subscriptions)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp get_filtered_subscriptions(assigns) do
    subscriptions = EmailSubscriptions.list_email_subscriptions()
    
    subscriptions
    |> filter_by_search(assigns.search_query)
    |> filter_by_status(assigns.status_filter)
    |> filter_by_source(assigns.source_filter)
    |> Enum.slice((assigns.page - 1) * assigns.per_page, assigns.per_page)
  end

  defp filter_by_search(subscriptions, ""), do: subscriptions
  defp filter_by_search(subscriptions, query) do
    subscriptions
    |> Enum.filter(fn sub -> 
      String.contains?(String.downcase(sub.email), String.downcase(query))
    end)
  end

  defp filter_by_status(subscriptions, "all"), do: subscriptions
  defp filter_by_status(subscriptions, status) do
    subscriptions
    |> Enum.filter(fn sub -> sub.status == status end)
  end

  defp filter_by_source(subscriptions, "all"), do: subscriptions
  defp filter_by_source(subscriptions, source) do
    subscriptions
    |> Enum.filter(fn sub -> sub.source == source end)
  end

  defp generate_csv(subscriptions) do
    headers = ["Email", "Source", "Status", "Subscribed At", "Unsubscribed At"]
    
    rows = subscriptions
    |> Enum.map(fn sub -> 
      [
        sub.email,
        sub.source,
        sub.status,
        safe_format_date(sub.subscribed_at),
        safe_format_date(sub.unsubscribed_at)
      ]
    end)
    
    [headers | rows]
    |> CSV.encode()
    |> Enum.to_list()
    |> Enum.join("")
  end

  defp format_datetime(nil), do: ""
  defp format_datetime(datetime) do
    try do
      Calendar.strftime(datetime, Calendar.ISO, "%Y-%m-%d %H:%M:%S UTC")
    rescue
      _ -> "Invalid date"
    end
  end
  
  defp safe_format_date(nil), do: "-"
  defp safe_format_date(datetime) do
    "#{datetime.year}-#{String.pad_leading("#{datetime.month}", 2, "0")}-#{String.pad_leading("#{datetime.day}", 2, "0")}"
  end
  
  defp safe_format_time(nil), do: "-"
  defp safe_format_time(datetime) do
    "#{String.pad_leading("#{datetime.hour}", 2, "0")}:#{String.pad_leading("#{datetime.minute}", 2, "0")}"
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold mb-2">Email Subscriptions</h1>
        <p class="text-base-content/70">Manage email subscriptions from the landing page and other sources</p>
      </div>

      <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Total Subscriptions</div>
          <div class="stat-value text-primary"><%= @total_count %></div>
        </div>
        
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Active</div>
          <div class="stat-value text-success">
            <%= EmailSubscriptions.count_active_subscriptions() %>
          </div>
        </div>
        
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Unsubscribed</div>
          <div class="stat-value text-warning">
            <%= EmailSubscriptions.count_email_subscriptions() - EmailSubscriptions.count_active_subscriptions() %>
          </div>
        </div>
        
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Today</div>
          <div class="stat-value text-info">
            <%= count_today_subscriptions() %>
          </div>
        </div>
      </div>

      <!-- Filters and Search -->
      <div class="bg-base-100 rounded-lg shadow p-6 mb-8">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <!-- Search -->
          <div>
            <label class="label">
              <span class="label-text">Search Emails</span>
            </label>
            <form phx-submit="search" class="flex gap-2">
              <input 
                type="text" 
                name="query" 
                value={@search_query}
                placeholder="Enter email or part of email..."
                class="input input-bordered flex-1"
              />
              <button type="submit" class="btn btn-primary">Search</button>
            </form>
          </div>

          <!-- Status Filter -->
          <div>
            <label class="label">
              <span class="label-text">Status</span>
            </label>
            <select 
              phx-change="filter_status" 
              name="status" 
              class="select select-bordered w-full"
            >
              <option value="all" selected={@status_filter == "all"}>All Statuses</option>
              <option value="active" selected={@status_filter == "active"}>Active</option>
              <option value="unsubscribed" selected={@status_filter == "unsubscribed"}>Unsubscribed</option>
              <option value="bounced" selected={@status_filter == "bounced"}>Bounced</option>
            </select>
          </div>

          <!-- Source Filter -->
          <div>
            <label class="label">
              <span class="label-text">Source</span>
            </label>
            <select 
              phx-change="filter_source" 
              name="source" 
              class="select select-bordered w-full"
            >
              <option value="all" selected={@source_filter == "all"}>All Sources</option>
              <option value="landing_page" selected={@source_filter == "landing_page"}>Landing Page</option>
              <option value="checkout" selected={@source_filter == "checkout"}>Checkout</option>
              <option value="manual" selected={@source_filter == "manual"}>Manual</option>
            </select>
          </div>

          <!-- Export -->
          <div class="flex items-end">
            <button 
              phx-click="export_csv" 
              class="btn btn-outline btn-secondary w-full"
            >
              📊 Export CSV
            </button>
          </div>
        </div>
      </div>

      <!-- Subscriptions Table -->
      <div class="bg-base-100 rounded-lg shadow overflow-hidden">
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>Email</th>
                <th>Source</th>
                <th>Status</th>
                <th>Subscribed At</th>
                <th>Unsubscribed At</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for subscription <- @subscriptions do %>
                <tr>
                  <td>
                    <div class="flex items-center space-x-3">
                      <div class="avatar placeholder">
                        <div class="bg-neutral text-neutral-content rounded-full w-8">
                          <span class="text-xs">
                            <%= String.first(subscription.email) |> String.upcase() %>
                          </span>
                        </div>
                      </div>
                      <div>
                        <div class="font-bold"><%= subscription.email %></div>
                        <div class="text-sm opacity-50">ID: <%= String.slice(subscription.id, 0, 8) %></div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="badge badge-outline">
                      <%= subscription.source %>
                    </span>
                  </td>
                  <td>
                    <%= case subscription.status do %>
                      <% "active" -> %>
                        <span class="badge badge-success">Active</span>
                      <% "unsubscribed" -> %>
                        <span class="badge badge-warning">Unsubscribed</span>
                      <% "bounced" -> %>
                        <span class="badge badge-error">Bounced</span>
                      <% _ -> %>
                        <span class="badge badge-neutral"><%= subscription.status %></span>
                    <% end %>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= safe_format_date(subscription.subscribed_at) %>
                    </div>
                    <div class="text-xs opacity-50">
                      <%= safe_format_time(subscription.subscribed_at) %>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= safe_format_date(subscription.unsubscribed_at) %>
                    </div>
                    <div class="text-xs opacity-50">
                      <%= safe_format_time(subscription.unsubscribed_at) %>
                    </div>
                  </td>
                  <td>
                    <div class="flex gap-2">
                      <%= if subscription.status == "active" do %>
                        <button 
                          phx-click="unsubscribe" 
                          phx-value-id={subscription.id}
                          class="btn btn-warning btn-xs"
                          data-confirm="Are you sure you want to unsubscribe this email?"
                        >
                          Unsubscribe
                        </button>
                      <% end %>
                      <button 
                        phx-click="delete" 
                        phx-value-id={subscription.id}
                        class="btn btn-error btn-xs"
                        data-confirm="Are you sure you want to delete this subscription? This action cannot be undone."
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="flex justify-center p-4 border-t">
            <div class="join">
              <%= for page <- 1..@total_pages do %>
                <button 
                  phx-click="change_page" 
                  phx-value-page={page}
                  class={[
                    "join-item btn btn-sm",
                    if(page == @page, do: "btn-active", else: "btn-outline")
                  ]}
                >
                  <%= page %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Empty State -->
      <%= if Enum.empty?(@subscriptions) do %>
        <div class="text-center py-12">
          <div class="text-6xl mb-4">📧</div>
          <h3 class="text-xl font-semibold mb-2">No email subscriptions found</h3>
          <p class="text-base-content/70 mb-6">
            <%= if @search_query != "" or @status_filter != "all" or @source_filter != "all" do %>
              Try adjusting your search criteria or filters.
            <% else %>
              No one has subscribed to emails yet.
            <% end %>
          </p>
        </div>
      <% end %>
    </div>

    <script>
      window.addEventListener("phx:download_csv", (e) => {
        const { data, filename } = e.detail;
        const blob = new Blob([data], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
      });
    </script>
    """
  end

  defp count_today_subscriptions do
    today = Date.utc_today()
    EmailSubscriptions.list_email_subscriptions()
    |> Enum.filter(fn sub -> 
      subscription_date = DateTime.to_date(sub.subscribed_at)
      Date.compare(subscription_date, today) == :eq
    end)
    |> length()
  end
end
