defmodule ShompWeb.StoreLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Stores

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Stores.get_store_by_slug_with_user(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}

      store ->
        # Load products for this store using the immutable store_id
        products = Shomp.Products.list_products_by_store(store.store_id)
        {:ok, assign(socket, store: store, products: products)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            <%= @store.name %>
          </h1>
          
          <%= if @store.description do %>
            <p class="text-xl text-gray-600 max-w-2xl mx-auto">
              <%= @store.description %>
            </p>
          <% end %>
        </div>

        <div class="bg-white rounded-lg shadow-lg p-8">
          <div class="text-center">
            <h2 class="text-2xl font-semibold text-gray-800 mb-4">
              Welcome to <%= @store.name %>
            </h2>
            
            <p class="text-gray-600 mb-8">
              This store is currently being set up. Products will be available soon!
            </p>

            <%= if @current_scope && @current_scope.user && @current_scope.user.id == @store.user_id do %>
              <div class="space-y-4">
                <.link
                  navigate={~p"/dashboard/store"}
                  class="btn btn-primary"
                >
                  Manage Store
                </.link>
                
                <.link
                  navigate={~p"/dashboard/products/new"}
                  class="btn btn-secondary"
                >
                  Add Product
                </.link>
              </div>
            <% else %>
              <div class="text-gray-500">
                <p>Store owner: <%= @store.user.username || "Creator" %></p>
              </div>
            <% end %>
          </div>
        </div>

        <%= if Enum.empty?(@products) do %>
          <div class="text-center py-12">
            <div class="text-gray-500 text-lg mb-4">
              No products available yet.
            </div>
            <%= if @current_scope && @current_scope.user && @current_scope.user.id == @store.user_id do %>
              <.link
                navigate={~p"/dashboard/products/new"}
                class="btn btn-primary"
              >
                Add Your First Product
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="mt-12">
            <h2 class="text-2xl font-semibold text-gray-800 mb-6">Products</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for product <- @products do %>
                <div class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow duration-300">
                  <div class="p-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-2">
                      <.link
                        navigate={~p"/#{@store.slug}/products/#{product.id}"}
                        class="hover:text-blue-600 transition-colors duration-200"
                      >
                        <%= product.title %>
                      </.link>
                    </h3>
                    
                    <%= if product.description do %>
                      <p class="text-gray-600 mb-4 line-clamp-2">
                        <%= product.description %>
                      </p>
                    <% end %>
                    
                    <div class="flex items-center justify-between">
                      <div class="text-lg font-bold text-green-600">
                        $<%= product.price %>
                      </div>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        <%= String.capitalize(product.type) %>
                      </span>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
