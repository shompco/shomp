defmodule ShompWeb.StoreLive.New do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Stores

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="text-center">
          <.header>
            Create Your Store
            <:subtitle>Set up your digital storefront to start selling</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="store_form" phx-submit="save" phx-change="validate">
          <div phx-hook="UsCitizenshipValidation" id="us-citizenship-validation">
          <.input
            field={@form[:name]}
            type="text"
            label="Store Name"
            placeholder="My Awesome Store"
            error_class="text-warning"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:slug]}
            type="text"
            label="Store URL"
            placeholder="my-awesome-store"
            error_class="text-warning"
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Tell customers what your store is about..."
            error_class="text-warning"
          />

          <div class="form-control">
            <label class="label cursor-pointer justify-start gap-3">
              <input type="hidden" name="store[us_citizen_confirmation]" value="false" />
              <input
                type="checkbox"
                id="store_us_citizen_confirmation"
                name="store[us_citizen_confirmation]"
                value="true"
                checked={@form[:us_citizen_confirmation].value}
                class="checkbox checkbox-primary"
                required
              />
              <span class="label-text text-base">
                I am a US citizen.
              </span>
            </label>
            <%= if @form.errors[:us_citizen_confirmation] do %>
              <div class="mt-1.5 flex gap-2 items-center text-sm text-warning">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.725-1.36 3.49 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                </svg>
                <%= elem(@form.errors[:us_citizen_confirmation], 0) %>
              </div>
            <% end %>
          </div>

          <.button phx-disable-with="Creating store..." class="btn btn-primary w-full" id="create-store-btn">
            Create Store
          </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    changeset = Stores.change_store_creation(%Stores.Store{})

    {:ok, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("validate", %{"store" => store_params}, socket) do
    changeset =
      %Stores.Store{}
      |> Stores.change_store_creation(store_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"store" => store_params}, socket) do
    user = socket.assigns.current_scope.user
    store_params = Map.put(store_params, "user_id", user.id)

    case Stores.create_store(store_params) do
      {:ok, store} ->
        {:noreply,
         socket
         |> put_flash(:info, "Store created successfully!")
         |> push_navigate(to: ~p"/stores/#{store.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "store")
    assign(socket, form: form)
  end
end
