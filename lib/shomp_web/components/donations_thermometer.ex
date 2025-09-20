defmodule ShompWeb.Components.DonationsThermometer do
  use ShompWeb, :html

  alias Shomp.Donations

  def donations_thermometer(assigns) do
    goal = Donations.get_current_goal()
    donor_count = Donations.get_donor_count()

    assigns = assign(assigns, goal: goal, donor_count: donor_count)

    ~H"""
    <!-- Mission Statement -->
    <div class="py-12 bg-base-100">
      <div class="container mx-auto px-4 text-center">
        <div class="max-w-4xl mx-auto">
          <blockquote class="text-lg md:text-xl font-light text-base-content/90 leading-relaxed italic">
            <span class="text-6xl text-primary/30 leading-none">"</span>
            Shomp is organized exclusively for charitable and educational purposes, including promoting public access to the arts and supporting U.S. artists and creators through a nonprofit e-commerce platform. By eliminating exploitative fees, providing educational resources, open-source tools, and community programs, Shomp seeks to empower creators, broaden public engagement with creative works, and strengthen the cultural and economic vitality of communities.
            <span class="text-6xl text-primary/30 leading-none">"</span>
          </blockquote>
        </div>
      </div>
    </div>

    <!-- Donations Thermometer -->
    <div class="bg-base-200 py-6">
      <div class="mx-auto max-w-6xl px-4">
        <%= if @goal do %>
          <div class="mb-6">
            <!-- Goal Header -->
            <div class="flex items-center justify-between mb-2">
              <h4 class="font-medium text-base-content"><%= @goal.title %></h4>
              <div class="text-right">
                <span class="text-lg font-bold text-primary">
                  $<%= format_amount(@goal.current_amount) %>
                </span>
                <span class="text-sm text-base-content/70">
                  of $<%= format_amount(@goal.target_amount) %>
                </span>
              </div>
            </div>

            <!-- Progress Bar -->
            <div class="w-full bg-base-300 rounded-full h-3 mb-2">
              <div
                class="bg-gradient-to-r from-primary to-secondary h-3 rounded-full transition-all duration-500 ease-out"
                style={"width: #{get_progress_percentage(@goal)}%"}
              >
              </div>
            </div>

            <!-- Progress Info -->
            <div class="flex items-center justify-between text-sm text-base-content/70">
              <span><%= get_progress_percentage(@goal) %>% funded</span>
              <span><%= @donor_count %> supporters</span>
            </div>
          </div>
        <% end %>

        <!-- Donate Button -->
        <div class="text-center">
          <.link
            href={~p"/payments/custom-donate"}
            class="btn btn-primary btn-lg"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
            </svg>
            Support Development
          </.link>
        </div>
      </div>
    </div>
    """
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
