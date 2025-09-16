defmodule ShompWeb.UserLive.Settings do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_sudo_mode}

  alias Shomp.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account tier and password settings</:subtitle>
        </.header>
      </div>

      <!-- Current Account Info (Read-only) -->
      <div class="bg-base-200 rounded-lg p-6 mb-6">
        <h3 class="text-lg font-semibold text-base-content mb-4">Account Information</h3>
        <div class="space-y-3">
          <div class="flex justify-between items-center">
            <span class="text-base-content/70">Email:</span>
            <span class="font-medium text-base-content"><%= @current_scope.user.email %></span>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-base-content/70">Username:</span>
            <span class="font-medium text-base-content">@<%= @current_scope.user.username %></span>
          </div>
        </div>
        <div class="mt-4 p-3 bg-info/10 rounded-lg">
          <p class="text-sm text-info">
            <strong>Note:</strong> Email and username cannot be changed for security reasons.
            If you need to update these, please contact support.
          </p>
        </div>
      </div>

      <!-- Current Plan Section -->
      <%= if @current_scope.user.tier do %>
        <div class="bg-base-200 rounded-lg p-6 mb-6">
          <h3 class="text-lg font-semibold text-base-content mb-4">Current Plan</h3>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-2xl font-bold text-primary"><%= @current_scope.user.tier.name %></p>
              <p class="text-base-content/70">
                $<%= @current_scope.user.tier.monthly_price %>/month
              </p>
              <div class="text-sm text-base-content/70 mt-2">
                <%= if @current_scope.user.tier.slug == "free" do %>
                  <p>• Unlimited Products</p>
                  <p>• Basic Support</p>
                <% end %>
                <%= if @current_scope.user.tier.slug == "plus" do %>
                  <p>• Unlimited Products</p>
                  <p>• Priority Support</p>
                  <p>• Support Shomp</p>
                <% end %>
                <%= if @current_scope.user.tier.slug == "pro" do %>
                  <p>• Unlimited Products</p>
                  <p>• Priority Support</p>
                  <p>• Support Shomp</p>
                  <p>• 1 of your Products Featured in Monthly Newsletter</p>
                <% end %>
              </div>
            </div>
            <div class="text-right">
              <a
                href={~p"/users/tier-upgrade"}
                class="btn btn-outline btn-primary">
                Change Plan
              </a>
            </div>
          </div>
        </div>
      <% else %>
        <div class="bg-warning/10 rounded-lg p-6 mb-6 border border-warning/20">
          <h3 class="text-lg font-semibold text-warning mb-4">No Plan Selected</h3>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-warning mb-2">
                You haven't selected a plan yet. Choose a plan to start using Shomp!
              </p>
            </div>
            <div class="text-right">
              <a
                href={~p"/users/tier-selection"}
                class="btn btn-primary">
                Choose Plan
              </a>
            </div>
          </div>
        </div>
      <% end %>

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          autocomplete="username"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    # Preload tier information
    user_with_tier = Shomp.Repo.preload(user, :tier)

    # If user doesn't have a tier, assign the default tier
    user_with_tier = if user_with_tier.tier_id && !user_with_tier.tier do
      # The tier_id exists but tier wasn't loaded, try to reload
      Shomp.Repo.preload(user_with_tier, :tier, force: true)
    else
      user_with_tier
    end

    password_changeset = Accounts.change_user_password(user_with_tier, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user_with_tier.email)
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:current_scope, %{socket.assigns.current_scope | user: user_with_tier})

    {:ok, socket}
  end


  @impl true
  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  @impl true
  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
