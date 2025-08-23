defmodule ShompWeb.StoreLive.Edit do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Stores

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # Get the user's store (assuming one store per user for now)
    case Stores.get_stores_by_user(user.id) do
      [store | _] ->
        changeset = Stores.change_store(store)
        {:ok, assign(socket, store: store, form: to_form(changeset))}
      
      [] ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have a store yet. Create one first!")
         |> push_navigate(to: ~p"/stores/new")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="text-center">
          <.header>
            Edit Store Settings
            <:subtitle>Update your store information and appearance</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="store_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:name]}
            type="text"
            label="Store Name"
            required
          />

          <.input
            field={@form[:slug]}
            type="text"
            label="Store URL"
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
          />

          <div class="flex gap-4">
            <.button phx-disable-with="Saving..." class="btn btn-primary flex-1">
              Save Changes
            </.button>
            
            <.link
              navigate={~p"/#{@store.slug}"}
              class="btn btn-secondary flex-1"
            >
              View Store
            </.link>
          </div>
        </.form>

        <div class="divider" />

        <div class="text-center">
          <h3 class="text-lg font-semibold text-gray-800 mb-4">Danger Zone</h3>
          <p class="text-gray-600 mb-4">
            Once you delete a store, there is no going back. Please be certain.
          </p>
          <button
            phx-click="delete_store"
            phx-confirm="Are you sure you want to delete this store? This action cannot be undone."
            class="btn btn-error"
          >
            Delete Store
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"store" => store_params}, socket) do
    changeset =
      socket.assigns.store
      |> Stores.change_store(store_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"store" => store_params}, socket) do
    case Stores.update_store(socket.assigns.store, store_params) do
      {:ok, store} ->
        {:noreply,
         socket
         |> put_flash(:info, "Store updated successfully!")
         |> push_navigate(to: ~p"/#{store.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_store", _params, socket) do
    case Stores.delete_store(socket.assigns.store) do
      {:ok, _store} ->
        {:noreply,
         socket
         |> put_flash(:info, "Store deleted successfully!")
         |> push_navigate(to: ~p"/")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete store. Please try again.")}
    end
  end
end
