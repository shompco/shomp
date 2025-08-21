defmodule ShompWeb.ProductLive.Edit do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Products

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    product = Products.get_product_with_store!(id)
    
    # Check if user owns the store
    if product.store.user_id == user.id do
      changeset = Products.change_product(product)
      {:ok, assign(socket, product: product, form: to_form(changeset))}
    else
      {:ok,
       socket
       |> put_flash(:error, "You can only edit products in your own store")
       |> push_navigate(to: ~p"/#{product.store.slug}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="text-center">
          <.header>
            Edit Product
            <:subtitle>Update your product information</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="product_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:title]}
            type="text"
            label="Product Title"
            required
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
          />

          <.input
            field={@form[:price]}
            type="number"
            label="Price"
            step="0.01"
            min="0.01"
            required
          />

          <.input
            field={@form[:type]}
            type="select"
            label="Product Type"
            options={[
              {"Digital Product", "digital"},
              {"Physical Product", "physical"},
              {"Service", "service"}
            ]}
            required
          />

          <%= if @form[:type].value == "digital" do %>
            <.input
              field={@form[:file_path]}
              type="text"
              label="File Path"
              required
            />
          <% end %>

          <div class="flex gap-4">
            <.button phx-disable-with="Saving..." class="btn btn-primary flex-1">
              Save Changes
            </.button>
            
            <.link
              navigate={~p"/#{@product.store.slug}/products/#{@product.id}"}
              class="btn btn-secondary flex-1"
            >
              View Product
            </.link>
          </div>
          
          <div class="mt-6 pt-6 border-t border-base-300">
            <button
              type="button"
              phx-click="delete_product"
              phx-confirm="Are you sure you want to delete this product? This action cannot be undone."
              class="btn btn-error w-full"
            >
              Delete Product
            </button>
          </div>
        </.form>
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

  def handle_event("save", %{"product" => product_params}, socket) do
    case Products.update_product(socket.assigns.product, product_params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully!")
         |> push_navigate(to: ~p"/#{product.store.slug}/products/#{product.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_product", _params, socket) do
    case Products.delete_product(socket.assigns.product) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted successfully!")
         |> push_navigate(to: ~p"/#{socket.assigns.product.store.slug}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete product. Please try again.")}
    end
  end
end
