defmodule ShompWeb.AdminLive.ProductEdit do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Products
  alias Shomp.Categories
  alias Shomp.StoreCategories
  alias Shomp.AdminLogs

  @page_title "Admin - Edit Product"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Check if user is admin
    if socket.assigns.current_scope &&
       socket.assigns.current_scope.user.email == @admin_email do

      product = Products.get_product_with_store!(id)

      # Load categories based on current product type
      filtered_category_options = if product.type do
        Categories.get_categories_by_type(product.type)
      else
        []
      end

      # Load custom categories for the store
      custom_category_options = StoreCategories.get_store_category_options_with_default(product.store_id)

      changeset = Products.change_product(product)

      {:ok, assign(socket,
        product: product,
        form: to_form(changeset),
        filtered_category_options: filtered_category_options,
        custom_category_options: custom_category_options,
        page_title: @page_title
      )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <div class="mb-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Admin Edit Product</h1>
              <p class="text-gray-600 mt-2">
                Editing: <span class="font-semibold"><%= @product.title %></span>
                from store <span class="font-semibold"><%= @product.store.name %></span>
              </p>
            </div>
            <div class="flex gap-2">
              <.link
                navigate={~p"/admin/products"}
                class="btn btn-outline"
              >
                ← Back to Products
              </.link>
              <.link
                navigate={~p"/admin"}
                class="btn btn-outline"
              >
                Admin Dashboard
              </.link>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Edit Form -->
          <div class="lg:col-span-2">
            <div class="bg-white rounded-lg shadow-lg p-6">
              <h2 class="text-xl font-semibold mb-4">Product Information</h2>

              <.form for={@form} id="product_form" phx-submit="save" phx-change="validate">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <.input
                    field={@form[:title]}
                    type="text"
                    label="Product Title"
                    required
                  />

                  <.input
                    field={@form[:price]}
                    type="number"
                    label="Price"
                    step="0.01"
                    min="0.01"
                    required
                  />
                </div>

                <.input
                  field={@form[:description]}
                  type="textarea"
                  label="Description"
                  rows="4"
                />

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <.input
                    field={@form[:type]}
                    type="select"
                    label="Product Type"
                    options={[
                      {"Physical Product", "physical"},
                      {"Digital Product", "digital"}
                    ]}
                    required
                    phx-change="type_changed"
                  />

                  <.input
                    field={@form[:category_id]}
                    type="select"
                    label="Platform Category"
                    options={@filtered_category_options}
                    prompt="Select a platform category"
                    required
                  />
                </div>

                <.input
                  field={@form[:custom_category_id]}
                  type="select"
                  label="Store Category (Optional)"
                  options={@custom_category_options}
                  prompt="Select a store category to organize your products"
                />

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <.input
                    field={@form[:slug]}
                    type="text"
                    label="Product Slug"
                  />

                  <.input
                    field={@form[:file_path]}
                    type="text"
                    label="Digital File Path"
                  />
                </div>

                <div class="flex gap-4 mt-6">
                  <button type="submit" class="btn btn-primary">
                    Save Changes
                  </button>
                  <button type="button" phx-click="cancel" class="btn btn-outline">
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <!-- Product Info & Actions -->
          <div class="space-y-6">
            <!-- Current Product Info -->
            <div class="bg-white rounded-lg shadow-lg p-6">
              <h3 class="text-lg font-semibold mb-4">Current Product Info</h3>
              <div class="space-y-3 text-sm">
                <div>
                  <span class="font-medium text-gray-600">ID:</span>
                  <span class="ml-2"><%= @product.id %></span>
                </div>
                <div>
                  <span class="font-medium text-gray-600">Created:</span>
                  <span class="ml-2"><%= Calendar.strftime(@product.inserted_at, "%b %d, %Y at %I:%M %p") %></span>
                </div>
                <div>
                  <span class="font-medium text-gray-600">Last Updated:</span>
                  <span class="ml-2"><%= Calendar.strftime(@product.updated_at, "%b %d, %Y at %I:%M %p") %></span>
                </div>
                <div>
                  <span class="font-medium text-gray-600">Store:</span>
                  <span class="ml-2"><%= @product.store.name %></span>
                </div>
                <div>
                  <span class="font-medium text-gray-600">Store ID:</span>
                  <span class="ml-2"><%= @product.store_id %></span>
                </div>
              </div>
            </div>

            <!-- Quick Actions -->
            <div class="bg-white rounded-lg shadow-lg p-6">
              <h3 class="text-lg font-semibold mb-4">Quick Actions</h3>
              <div class="space-y-3">
                <.link
                  navigate={~p"/stores/#{@product.store.slug}/products/#{@product.slug}"}
                  class="btn btn-outline w-full"
                  target="_blank"
                >
                  View Product
                </.link>

                <.link
                  navigate={~p"/stores/#{@product.store.slug}"}
                  class="btn btn-outline w-full"
                  target="_blank"
                >
                  View Store
                </.link>

                <button
                  phx-click="delete_product"
                  phx-confirm="Are you sure you want to delete this product? This action cannot be undone."
                  class="btn btn-error w-full"
                >
                  Delete Product
                </button>
              </div>
            </div>

            <!-- Admin Notes -->
            <div class="bg-white rounded-lg shadow-lg p-6">
              <h3 class="text-lg font-semibold mb-4">Admin Notes</h3>
              <div class="space-y-3">
                <div class="text-sm text-gray-600">
                  <p>• All changes are logged for audit purposes</p>
                  <p>• Changes are immediately visible to customers</p>
                  <p>• Use caution when editing live products</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Products.change_product(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("type_changed", %{"product" => %{"type" => product_type}}, socket) do
    filtered_category_options = if product_type && product_type != "" do
      Categories.get_categories_by_type(product_type)
    else
      Categories.get_main_category_options()
    end

    {:noreply, assign(socket, filtered_category_options: filtered_category_options)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    product = socket.assigns.product

    # Store the product state before changes for logging
    product_before = %{
      title: product.title,
      description: product.description,
      price: if(product.price, do: Decimal.to_string(product.price), else: nil),
      type: product.type,
      category_id: product.category_id,
      custom_category_id: product.custom_category_id,
      slug: product.slug,
      file_path: product.file_path
    }

    case Products.update_product(product, product_params) do
      {:ok, updated_product} ->
        # Log the admin action
        changes = Map.take(product_params, ["title", "description", "price", "type", "category_id", "custom_category_id", "slug", "file_path"])

        product_after = %{
          title: updated_product.title,
          description: updated_product.description,
          price: if(updated_product.price, do: Decimal.to_string(updated_product.price), else: nil),
          type: updated_product.type,
          category_id: updated_product.category_id,
          custom_category_id: updated_product.custom_category_id,
          slug: updated_product.slug,
          file_path: updated_product.file_path
        }

        # Only log if there were actual changes
        if map_size(changes) > 0 do
          AdminLogs.log_product_edit(
            socket.assigns.current_scope.user.id,
            product.id,
            changes,
            product_before,
            product_after
          )
        end

        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully!")
         |> assign(product: updated_product)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_product", _params, socket) do
    product = socket.assigns.product

    case Products.delete_product(product) do
      {:ok, _deleted_product} ->
        # Log the deletion
        AdminLogs.log_product_deletion(
          socket.assigns.current_scope.user.id,
          product.id,
          %{
            title: product.title,
            store_id: product.store_id,
            price: if(product.price, do: Decimal.to_string(product.price), else: nil)
          }
        )

        # Redirect to success page with product details
        success_url = ~p"/admin/delete-success?entity_type=product&entity_name=#{URI.encode(product.title)}&entity_id=#{product.id}"

        {:noreply,
         socket
         |> put_flash(:info, "Product deleted successfully!")
         |> push_navigate(to: success_url)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete product")}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/products")}
  end
end
