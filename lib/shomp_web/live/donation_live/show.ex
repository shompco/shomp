defmodule ShompWeb.DonationLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Donations

  def mount(_params, _session, socket) do
    goal = Donations.get_current_goal()

    {:ok, assign(socket,
      goal: goal,
      selected_amount: 25,
      custom_amount: nil
    )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-base-content mb-4">
            Support Shomp Development
          </h1>
          <p class="text-lg text-base-content/70">
            Your donations help us build new features and keep Shomp free for creators.
          </p>
        </div>

        <!-- Goal Progress -->
        <%= if @goal do %>
          <div class="card bg-base-100 shadow-lg mb-8">
            <div class="card-body">
              <h3 class="card-title"><%= @goal.title %></h3>
              <p class="text-base-content/70 mb-4"><%= @goal.description %></p>

              <div class="space-y-2">
                <div class="flex justify-between text-sm">
                  <span>Progress</span>
                  <span class="font-semibold">
                    $<%= format_amount(@goal.current_amount) %> / $<%= format_amount(@goal.target_amount) %>
                  </span>
                </div>

                <div class="w-full bg-base-300 rounded-full h-3">
                  <div
                    class="bg-primary h-3 rounded-full transition-all duration-300"
                    style={"width: #{get_progress_percentage(@goal)}%"}
                  >
                  </div>
                </div>

                <div class="text-center text-sm text-base-content/70">
                  <%= get_progress_percentage(@goal) %>% funded
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Donation Form -->
        <div class="card bg-base-100 shadow-lg">
          <div class="card-body">
            <h3 class="card-title mb-4">Make a Donation</h3>

            <!-- Suggested Amounts -->
            <div class="mb-6">
              <label class="label">
                <span class="label-text font-medium">Choose Amount</span>
              </label>
              <div class="grid grid-cols-2 md:grid-cols-5 gap-2 mb-4">
                <%= for amount <- [5, 10, 25, 50, 100] do %>
                  <button
                    type="button"
                    class={[
                      "btn",
                      if(@selected_amount == amount, do: "btn-primary", else: "btn-outline")
                    ]}
                    phx-click="select_amount"
                    phx-value-amount={amount}
                  >
                    $<%= amount %>
                  </button>
                <% end %>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Custom Amount</span>
                </label>
                <input
                  type="number"
                  name="custom_amount"
                  placeholder="Enter amount"
                  class="input input-bordered"
                  phx-keyup="update_custom_amount"
                  phx-debounce="300"
                />
              </div>
            </div>

            <!-- Donor Information -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Your Name (Optional)</span>
                </label>
                <input
                  type="text"
                  name="donor_name"
                  placeholder="How should we thank you?"
                  class="input input-bordered"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Email (Optional)</span>
                </label>
                <input
                  type="email"
                  name="donor_email"
                  placeholder="For receipt"
                  class="input input-bordered"
                />
              </div>
            </div>

            <!-- Message -->
            <div class="form-control mb-6">
              <label class="label">
                <span class="label-text">Message (Optional)</span>
              </label>
              <textarea
                name="message"
                placeholder="Leave a message of support..."
                class="textarea textarea-bordered h-20"
              ></textarea>
            </div>

            <!-- Privacy Options -->
            <div class="form-control mb-6">
              <label class="label cursor-pointer">
                <input type="checkbox" name="is_anonymous" class="checkbox" />
                <span class="label-text">Donate anonymously</span>
              </label>
            </div>

            <!-- Donate Button -->
            <div class="text-center">
              <button
                type="button"
                class="btn btn-primary btn-lg"
                phx-click="process_donation"
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </svg>
                Donate $<%= @selected_amount %>
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("select_amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, selected_amount: String.to_integer(amount), custom_amount: nil)}
  end

  def handle_event("update_custom_amount", %{"value" => ""}, socket) do
    {:noreply, assign(socket, custom_amount: nil)}
  end

  def handle_event("update_custom_amount", %{"value" => value}, socket) do
    case Integer.parse(value) do
      {amount, ""} when amount > 0 ->
        {:noreply, assign(socket, selected_amount: amount, custom_amount: amount)}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("process_donation", _params, socket) do
    # This would integrate with your existing Stripe payment system
    # For now, just show a message
    {:noreply, put_flash(socket, :info, "Donation processing would be implemented here with Stripe integration")}
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
