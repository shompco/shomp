# Shomp MVP Core 17 - Donations Tracking Thermometer

## Overview
Add a simple donations tracking thermometer to the site footer that shows progress toward a single funding goal, encouraging community support.

## Core Features

### 1. Donations Thermometer Display
- **Visual Progress Bar**: Animated thermometer showing donation progress
- **Goal Tracking**: Display current amount raised vs. target goal
- **Real-time Updates**: Live updates when new donations come in
- **Responsive Design**: Works on all screen sizes

### 2. Donation Goals Management
- **Admin Dashboard**: Manage current donation goal with Reset Progress button

### 3. Donation Integration
- **Stripe Integration**: Connect with existing payment system
- **Donation Amounts**: Suggested amounts ($5, $10, $25, $50, custom)
- **Anonymous Donations**: Option to donate without showing name
- **Donation Messages**: Optional message with donation
- **Thank You Page**: Confirmation and appreciation

### 4. Analytics & Transparency
- **Public Transparency**: Show total raised, number of donors
- **Recent Donations**: Display recent donation amount in toaster notification (only user initials shown)

## Database Schema

### Donation Goals Table
```elixir
create table(:donation_goals) do
  add :id, :bigserial, primary_key: true
  add :title, :string, null: false
  add :description, :text, null: false
  add :target_amount, :decimal, precision: 10, scale: 2, null: false
  add :current_amount, :decimal, precision: 10, scale: 2, default: 0.0
  add :status, :string, default: "active" # active, completed, paused
  
  timestamps()
end
```

### Donations Table
```elixir
create table(:donations) do
  add :id, :bigserial, primary_key: true
  add :donation_goal_id, references(:donation_goals, type: :bigserial), null: true
  add :user_id, references(:users, type: :bigserial), null: true
  add :amount, :decimal, precision: 10, scale: 2, null: false
  add :stripe_payment_intent_id, :string, null: false
  add :donor_name, :string, null: true # Optional display name
  add :donor_email, :string, null: true
  add :message, :text, null: true # Optional message
  add :is_anonymous, :boolean, default: false
  add :is_public, :boolean, default: true # Show in recent donations
  add :status, :string, default: "completed" # completed, failed, refunded
  
  timestamps()
end

create index(:donations, [:donation_goal_id])
create index(:donations, [:user_id])
create index(:donations, [:status])
create index(:donations, [:is_public])
create index(:donations, [:inserted_at])
```

## Implementation

### 1. Footer Thermometer Component
```elixir
defmodule ShompWeb.Components.DonationsThermometer do
  use ShompWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="bg-base-200 py-6 mt-12">
      <div class="mx-auto max-w-6xl px-4">
        <div class="text-center mb-4">
          <h3 class="text-lg font-semibold text-base-content mb-2">
            Support Shomp Development
          </h3>
          <p class="text-sm text-base-content/70">
            Help us build the future of creator commerce
          </p>
        </div>

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

            <!-- Description -->
            <p class="text-sm text-base-content/80 mt-2">
              <%= @goal.description %>
            </p>
          </div>
        <% end %>

        <!-- Donate Button -->
        <div class="text-center">
          <.link
            navigate={~p"/donate"}
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

  def mount(socket) do
    goal = Shomp.Donations.get_current_goal()
    donor_count = Shomp.Donations.get_donor_count()
    {:ok, assign(socket, goal: goal, donor_count: donor_count)}
  end

  defp get_progress_percentage(goal) do
    if goal.target_amount > 0 do
      min(100, (goal.current_amount / goal.target_amount) * 100)
      |> Float.round(1)
    else
      0
    end
  end

  defp format_amount(amount) do
    :erlang.float_to_binary(amount, decimals: 0)
  end
end
```

### 2. Donations Context
```elixir
defmodule Shomp.Donations do
  @moduledoc """
  Handles donation goals and donations.
  """

  alias Shomp.Donations.{DonationGoal, Donation}
  alias Shomp.Repo

  @doc """
  Gets the current active donation goal.
  """
  def get_current_goal do
    from(g in DonationGoal, where: g.status == "active")
    |> Repo.one()
  end

  @doc """
  Creates or updates the current donation goal.
  """
  def set_goal(attrs) do
    case get_current_goal() do
      nil -> create_goal(attrs)
      goal -> update_goal(goal, attrs)
    end
  end

  @doc """
  Resets the current goal progress to zero.
  """
  def reset_goal_progress do
    case get_current_goal() do
      nil -> {:error, :no_goal}
      goal -> update_goal(goal, %{current_amount: 0.0})
    end
  end

  @doc """
  Records a new donation.
  """
  def record_donation(attrs) do
    with {:ok, donation} <- create_donation(attrs),
         :ok <- update_goal_amount(donation.donation_goal_id, donation.amount) do
      {:ok, donation}
    end
  end

  @doc """
  Gets donor count for current goal.
  """
  def get_donor_count do
    case get_current_goal() do
      nil -> 0
      goal ->
        from(d in Donation,
          where: d.donation_goal_id == ^goal.id and d.status == "completed",
          select: count(d.id)
        )
        |> Repo.one()
    end
  end

  defp create_goal(attrs) do
    %DonationGoal{}
    |> DonationGoal.changeset(attrs)
    |> Repo.insert()
  end

  defp update_goal(goal, attrs) do
    goal
    |> DonationGoal.changeset(attrs)
    |> Repo.update()
  end

  defp create_donation(attrs) do
    %Donation{}
    |> Donation.changeset(attrs)
    |> Repo.insert()
  end

  defp update_goal_amount(goal_id, amount) do
    goal = Repo.get(DonationGoal, goal_id)
    if goal do
      new_amount = goal.current_amount + amount
      update_goal(goal, %{current_amount: new_amount})
    else
      :ok
    end
  end
end
```

### 3. Simple Donation Page
```elixir
defmodule ShompWeb.DonationLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Donations

  def mount(_params, _session, socket) do
    goal = Donations.get_current_goal()
    
    {:ok, assign(socket, 
      goal: goal,
      selected_amount: 25
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
    {:noreply, assign(socket, selected_amount: String.to_integer(amount))}
  end

  def handle_event("process_donation", _params, socket) do
    # This would integrate with your existing Stripe payment system
    {:noreply, put_flash(socket, :info, "Donation processing would be implemented here")}
  end

  defp get_progress_percentage(goal) do
    if goal.target_amount > 0 do
      min(100, (goal.current_amount / goal.target_amount) * 100)
      |> Float.round(1)
    else
      0
    end
  end

  defp format_amount(amount) do
    :erlang.float_to_binary(amount, decimals: 0)
  end
end
```

### 4. Simple Admin Dashboard
```elixir
defmodule ShompWeb.AdminLive.Donations do
  use ShompWeb, :live_view

  alias Shomp.Donations

  def mount(_params, _session, socket) do
    goal = Donations.get_current_goal()
    donor_count = Donations.get_donor_count()
    
    {:ok, assign(socket, 
      goal: goal,
      donor_count: donor_count
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
      min(100, (goal.current_amount / goal.target_amount) * 100)
      |> Float.round(1)
    else
      0
    end
  end

  defp format_amount(amount) do
    :erlang.float_to_binary(amount, decimals: 0)
  end
end
```

## Routes
```elixir
# In router.ex
scope "/", ShompWeb do
  pipe_through :browser
  
  # Public donation page
  live "/donate", DonationLive.Show, :show
end

scope "/admin", ShompWeb do
  pipe_through [:browser, :require_authenticated_user, :require_admin]
  
  # Admin donation management
  live "/donations", AdminLive.Donations, :index
  live "/donations/goal/edit", AdminLive.DonationGoals, :edit
  live "/donations/goal/new", AdminLive.DonationGoals, :new
end
```

## Benefits

### For Platform
- **Community Funding**: Sustainable development funding
- **Transparency**: Public progress tracking builds trust
- **Engagement**: Community feels invested in platform success
- **Simple Management**: Easy admin controls with reset functionality

### For Users
- **Impact Visibility**: See how their support helps
- **Community Feel**: Part of something bigger
- **Recognition**: Optional public recognition for supporters
- **Simple Process**: Easy donation flow

This simplified thermometer system creates a sustainable funding model while building community engagement with minimal complexity.