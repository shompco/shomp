defmodule ShompWeb.ProductLive.New do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Products
  alias Shomp.Stores

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="text-center">
          <.header>
            Add New Product
            <:subtitle>Create a new product for your store</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="product_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:title]}
            type="text"
            label="Product Title"
            placeholder="Amazing Product"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Describe your product in detail..."
          />

          <.input
            field={@form[:price]}
            type="number"
            label="Price"
            placeholder="9.99"
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
              placeholder="/uploads/product-file.pdf"
              required
            />
          <% end %>

          <.button phx-disable-with="Creating product..." class="btn btn-primary w-full">
            Create Product
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # Get the user's store
    case Stores.get_stores_by_user(user.id) do
      [store | _] ->
        changeset = Products.change_product_creation(%Products.Product{})
        {:ok, assign_form(socket, changeset, store)}
      
      [] ->
        {:ok,
         socket
         |> put_flash(:error, "You need to create a store first!")
         |> push_navigate(to: ~p"/stores/new")}
    end
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      %Products.Product{}
      |> Products.change_product_creation(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset, socket.assigns.store)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    IO.puts("=== SAVE EVENT TRIGGERED ===")
    IO.puts("Product params: #{inspect(product_params)}")
    
    product_params = Map.put(product_params, "store_id", socket.assigns.store.id)

    case Products.create_product(product_params) do
      {:ok, _product} ->
        IO.puts("Product created successfully, redirecting...")
        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully!")
         |> push_navigate(to: ~p"/#{socket.assigns.store.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.puts("Product creation failed: #{inspect(changeset.errors)}")
        {:noreply, assign_form(socket, changeset, socket.assigns.store)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset, store) do
    form = to_form(changeset, as: "product")
    assign(socket, form: form, store: store)
  end
end
