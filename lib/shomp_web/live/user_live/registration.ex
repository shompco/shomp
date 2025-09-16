defmodule ShompWeb.UserLive.Registration do
  use ShompWeb, :live_view

  alias Shomp.Accounts
  alias Shomp.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:name]}
            type="text"
            label="Full Name"
            autocomplete="name"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:username]}
            type="text"
            label="Username"
            autocomplete="username"
            required
            placeholder="Choose a unique username (3-30 characters)"
          />

          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="email"
            required
          />

          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="new-password"
            required
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm Password"
            autocomplete="new-password"
            required
          />

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ShompWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Automatically log in the user after successful registration
        {:ok, token, _claims} = Accounts.generate_user_session_token(user)

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Account created successfully! Welcome to Shomp - let's start selling!"
         )
         |> push_navigate(to: ~p"/users/log-in?token=#{token}", external: true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
