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
          <.input
            field={@form[:name]}
            type="text"
            label="Store Name"
            placeholder="My Awesome Store"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:slug]}
            type="text"
            label="Store URL"
            placeholder="my-awesome-store"
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Tell customers what your store is about..."
          />

          <.button phx-disable-with="Creating store..." class="btn btn-primary w-full">
            Create Store
          </.button>
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
         |> push_navigate(to: ~p"/#{store.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "store")
    assign(socket, form: form)
  end
end
