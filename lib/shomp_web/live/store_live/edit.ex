defmodule ShompWeb.StoreLive.Edit do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Stores
  alias Shomp.StoreCategories
  alias Shomp.Categories.Category

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # Get the user's store (assuming one store per user for now)
    case Stores.get_stores_by_user(user.id) do
      [store | _] ->
        changeset = Stores.change_store(store)
        store_categories = StoreCategories.list_store_categories_with_counts(store.store_id)
        category_changeset = StoreCategories.change_store_category(%Category{})
        
        {:ok, assign(socket, 
          store: store, 
          form: to_form(changeset),
          store_categories: store_categories,
          category_form: to_form(category_changeset),
          show_category_form: false,
          editing_category: nil
        )}
      
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
      <div class="mx-auto max-w-4xl">
        <div class="text-center">
          <.header>
            Edit Store Settings
            <:subtitle>Update your store information and appearance</:subtitle>
          </.header>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Store Settings -->
          <div>
            <h3 class="text-lg font-semibold text-gray-800 mb-4">Store Information</h3>
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
                  navigate={~p"/stores/#{@store.slug}"}
                  class="btn btn-secondary flex-1"
                >
                  View Store
                </.link>
              </div>
            </.form>
          </div>

          <!-- Category Management -->
          <div>
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-gray-800">Custom Categories</h3>
              <button
                phx-click="show_category_form"
                class="btn btn-primary btn-sm"
              >
                Add Category
              </button>
            </div>

            <!-- Category Form -->
            <%= if @show_category_form do %>
              <.form for={@category_form} id="category_form" phx-submit="save_category" phx-change="validate_category">
                <div class="bg-gray-50 p-4 rounded-lg mb-4">
                  <h4 class="font-medium text-gray-700 mb-3">
                    <%= if @editing_category, do: "Edit Category", else: "New Category" %>
                  </h4>
                  
                  <.input
                    field={@category_form[:name]}
                    type="text"
                    label="Category Name"
                    required
                  />

                  <.input
                    field={@category_form[:slug]}
                    type="text"
                    label="Category URL"
                    placeholder="auto-generated from name"
                  />

                  <.input
                    field={@category_form[:description]}
                    type="textarea"
                    label="Description"
                  />

                  <.input
                    field={@category_form[:position]}
                    type="number"
                    label="Position"
                    value={@category_form[:position].value || 0}
                  />

                  <div class="flex gap-2 mt-3">
                    <.button type="submit" class="btn btn-primary btn-sm">
                      <%= if @editing_category, do: "Update", else: "Create" %>
                    </.button>
                    <button
                      type="button"
                      phx-click="cancel_category_form"
                      class="btn btn-secondary btn-sm"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </.form>
            <% end %>

            <!-- Categories List -->
            <div class="space-y-2">
              <%= for category <- @store_categories do %>
                <div class="flex items-center justify-between p-3 bg-white border rounded-lg">
                  <div class="flex-1">
                    <div class="font-medium text-gray-900"><%= category.name %></div>
                    <%= if category.description do %>
                      <div class="text-sm text-gray-600 mt-1"><%= category.description %></div>
                    <% end %>
                    <div class="text-xs text-gray-500 mt-1">
                      URL: /<%= @store.slug %>/<%= category.slug %> • <%= category.product_count %> products
                    </div>
                  </div>
                  <div class="flex gap-2">
                    <button
                      phx-click="edit_category"
                      phx-value-id={category.id}
                      class="btn btn-sm btn-outline"
                    >
                      Edit
                    </button>
                    <button
                      phx-click="delete_category"
                      phx-value-id={category.id}
                      phx-confirm="Are you sure? This will remove the category from all products."
                      class="btn btn-sm btn-error"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              <% end %>
              
              <%= if Enum.empty?(@store_categories) do %>
                <div class="text-center py-8 text-gray-500">
                  <p>No custom categories yet.</p>
                  <p class="text-sm">Create categories to organize your products.</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

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
         |> push_navigate(to: ~p"/stores/#{store.slug}")}

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

  # Category management events
  def handle_event("show_category_form", _params, socket) do
    category_changeset = StoreCategories.change_store_category(%Category{})
    {:noreply, assign(socket, 
      show_category_form: true, 
      category_form: to_form(category_changeset),
      editing_category: nil
    )}
  end

  def handle_event("cancel_category_form", _params, socket) do
    {:noreply, assign(socket, 
      show_category_form: false, 
      editing_category: nil
    )}
  end

  def handle_event("validate_category", %{"category" => category_params}, socket) do
    changeset = 
      %Category{}
      |> StoreCategories.change_store_category(category_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, category_form: to_form(changeset))}
  end

  def handle_event("save_category", %{"category" => category_params}, socket) do
    category_params = Map.put(category_params, "store_id", socket.assigns.store.store_id)
    
    case socket.assigns.editing_category do
      nil ->
        # Creating new category
        case StoreCategories.create_store_category(category_params) do
          {:ok, _category} ->
            store_categories = StoreCategories.list_store_categories_with_counts(socket.assigns.store.store_id)
            {:noreply, 
             socket
             |> put_flash(:info, "Category created successfully!")
             |> assign(store_categories: store_categories, show_category_form: false)}
          
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, category_form: to_form(changeset))}
        end
      
      category ->
        # Updating existing category
        case StoreCategories.update_store_category(category, category_params) do
          {:ok, _updated_category} ->
            store_categories = StoreCategories.list_store_categories_with_counts(socket.assigns.store.store_id)
            {:noreply, 
             socket
             |> put_flash(:info, "Category updated successfully!")
             |> assign(store_categories: store_categories, show_category_form: false, editing_category: nil)}
          
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, category_form: to_form(changeset))}
        end
    end
  end

  def handle_event("edit_category", %{"id" => category_id}, socket) do
    category = StoreCategories.get_store_category!(category_id)
    category_changeset = StoreCategories.change_store_category(category)
    
    {:noreply, assign(socket, 
      show_category_form: true, 
      category_form: to_form(category_changeset),
      editing_category: category
    )}
  end

  def handle_event("delete_category", %{"id" => category_id}, socket) do
    category = StoreCategories.get_store_category!(category_id)
    
    case StoreCategories.delete_store_category(category) do
      {:ok, _deleted_category} ->
        store_categories = StoreCategories.list_store_categories_with_counts(socket.assigns.store.store_id)
        {:noreply, 
         socket
         |> put_flash(:info, "Category deleted successfully!")
         |> assign(store_categories: store_categories)}
      
      {:error, _changeset} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to delete category. Please try again.")}
    end
  end
end
