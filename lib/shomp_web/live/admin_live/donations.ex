defmodule ShompWeb.AdminLive.Donations do
  use ShompWeb, :live_view

  alias Shomp.Donations

  def mount(_params, _session, socket) do
    goal = Donations.get_current_goal()
    donor_count = Donations.get_donor_count()
    stats = Donations.get_donation_stats()

    {:ok, assign(socket,
      goal: goal,
      donor_count: donor_count,
      stats: stats
    )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-3xl font-bold text-base-content">Donation Management</h1>
          <.link
            navigate={~p"/admin/donations/goal/edit"}
            class="btn btn-primary"
          >
            Edit Goal
          </.link>
        </div>

        <!-- Current Goal -->
        <%= if @goal do %>
          <div class="card bg-base-100 shadow-md mb-8">
            <div class="card-body">
              <h3 class="card-title"><%= @goal.title %></h3>
              <p class="text-base-content/70 mb-4"><%= @goal.description %></p>

              <div class="space-y-4">
                <div class="flex justify-between">
                  <span>Progress</span>
                  <span class="font-semibold">
                    $<%= format_amount(@goal.current_amount) %> / $<%= format_amount(@goal.target_amount) %>
                  </span>
                </div>

                <div class="w-full bg-base-300 rounded-full h-3">
                  <div
                    class="bg-primary h-3 rounded-full"
                    style={"width: #{get_progress_percentage(@goal)}%"}
                  >
                  </div>
                </div>

                <div class="flex justify-between text-sm text-base-content/70">
                  <span><%= get_progress_percentage(@goal) %>% funded</span>
                  <span><%= @donor_count %> supporters</span>
                </div>
              </div>

              <div class="card-actions justify-end mt-6">
                <button
                  class="btn btn-warning"
                  phx-click="reset_progress"
                >
                  Reset Progress
                </button>
                <.link
                  navigate={~p"/admin/donations/goal/edit"}
                  class="btn btn-outline"
                >
                  Edit Goal
                </.link>
              </div>
            </div>
          </div>

          <!-- Statistics -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
            <div class="stat bg-base-100 shadow rounded-lg">
              <div class="stat-title">Total Donations</div>
              <div class="stat-value text-primary"><%= @stats.total_donations %></div>
            </div>
            <div class="stat bg-base-100 shadow rounded-lg">
              <div class="stat-title">Total Amount</div>
              <div class="stat-value text-secondary">$<%= format_amount(@stats.total_amount) %></div>
            </div>
            <div class="stat bg-base-100 shadow rounded-lg">
              <div class="stat-title">Average Donation</div>
              <div class="stat-value text-accent">$<%= format_amount(@stats.average_donation) %></div>
            </div>
          </div>
        <% else %>
          <div class="text-center py-12">
            <h3 class="text-lg font-medium text-base-content mb-2">No donation goal set</h3>
            <p class="text-base-content/70 mb-6">Create a donation goal to start collecting support.</p>
            <.link
              navigate={~p"/admin/donations/goal/new"}
              class="btn btn-primary"
            >
              Create Goal
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("reset_progress", _params, socket) do
    case Donations.reset_goal_progress() do
      {:ok, _goal} ->
        {:noreply, put_flash(socket, :info, "Goal progress reset successfully")}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to reset progress: #{inspect(reason)}")}
    end
  end

  defp get_progress_percentage(goal) do
    if goal.target_amount > 0 do
      min(100, (Decimal.to_float(goal.current_amount) / Decimal.to_float(goal.target_amount)) * 100)
      |> Float.round(1)
    else
      0
    end
  end

  defp format_amount(amount) do
    amount
    |> Decimal.to_float()
    |> :erlang.float_to_binary(decimals: 0)
  end
end
