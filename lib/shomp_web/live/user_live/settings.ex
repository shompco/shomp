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
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form for={@username_form} id="username_form" phx-submit="update_username" phx-change="validate_username">
        <.input
          field={@username_form[:username]}
          type="text"
          label="Username"
          autocomplete="username"
          required
          placeholder={@current_scope.user.username || "Choose a unique username (3-30 characters)"}
        />
        <div class="text-sm text-gray-600 mb-2">
          Current username: <span class="font-medium">@<%= @current_scope.user.username %></span>
        </div>
        <.button variant="primary" phx-disable-with="Changing...">Change Username</.button>
      </.form>

      <div class="divider" />

      <!-- Current Plan Section -->
      <%= if @current_scope.user.tier do %>
        <div class="bg-gray-50 rounded-lg p-6 mb-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Current Plan</h3>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-2xl font-bold text-blue-600"><%= @current_scope.user.tier.name %></p>
              <p class="text-gray-600">
                $<%= @current_scope.user.tier.monthly_price %>/month
              </p>
              <p class="text-sm text-gray-500 mt-1">
                <%= @current_scope.user.tier.store_limit %> stores • 
                <%= @current_scope.user.tier.product_limit_per_store %> products per store
              </p>
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
        <div class="bg-yellow-50 rounded-lg p-6 mb-6 border border-yellow-200">
          <h3 class="text-lg font-semibold text-yellow-800 mb-4">No Plan Selected</h3>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-yellow-700 mb-2">
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
    
    email_changeset = Accounts.change_user_email(user_with_tier, %{}, validate_unique: false)
    username_changeset = Accounts.change_user_username(user_with_tier, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user_with_tier, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user_with_tier.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:username_form, to_form(username_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:current_scope, %{socket.assigns.current_scope | user: user_with_tier})

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("validate_username", params, socket) do
    %{"user" => user_params} = params

    username_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_username(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, username_form: username_form)}
  end

  def handle_event("update_username", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_username(user, user_params) do
      {:ok, updated_user} ->
        # Update the current_scope with the fresh user data
        updated_current_scope = %{socket.assigns.current_scope | user: updated_user}
        
        {:noreply, 
         socket
         |> assign(:current_scope, updated_current_scope)
         |> put_flash(:info, "Username updated successfully!")
         |> assign(:username_form, to_form(Accounts.change_user_username(updated_user, %{}, validate_unique: false)))}

      {:error, changeset} ->
        {:noreply, assign(socket, :username_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

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
