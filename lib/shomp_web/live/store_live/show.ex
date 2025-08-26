defmodule ShompWeb.StoreLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Stores
  alias Shomp.StoreCategories

  # Mount function for category listing page: /:store_slug/:category_slug
  def mount(%{"store_slug" => store_slug, "category_slug" => category_slug}, _session, socket) do
    case Stores.get_store_by_slug_with_user(store_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}

      store ->
        # Get the custom category by slug within the store
        case StoreCategories.get_store_category_by_slug(store.store_id, category_slug) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Category not found")
             |> push_navigate(to: ~p"/#{store_slug}")}
          
          category ->
            # Load products in this specific category
            products = Shomp.Products.get_products_by_custom_category(category.id)
            
            {:ok, assign(socket, 
              store: store, 
              category: category,
              products: products,
              custom_categories: [],
              products_by_category: %{},
              show_category_page: true
            )}
        end
    end
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # Redirect to home if slug is empty
    if slug == "" or slug == nil do
      {:ok, socket |> push_navigate(to: ~p"/")}
    else
      case Stores.get_store_by_slug_with_user(slug) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, "Store not found")
           |> push_navigate(to: ~p"/")}

        store ->
        # Load products for this store using the immutable store_id
        products = Shomp.Products.list_products_by_store(store.store_id)
        
        # Load custom categories for this store
        custom_categories = Shomp.StoreCategories.list_store_categories_with_counts(store.store_id)
        
        # Group products by custom category
        products_by_category = Enum.group_by(products, fn product -> 
          if product.custom_category_id do
            Enum.find(custom_categories, fn cat -> cat.id == product.custom_category_id end)
          else
            nil
          end
        end)
        
        {:ok, assign(socket, 
          store: store, 
          products: products, 
          custom_categories: custom_categories,
          products_by_category: products_by_category
        )}
      end
    end
  end



  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8">
        <%= if assigns[:show_category_page] do %>
          <!-- Category Listing Page -->
          <div class="mb-8">
            <nav class="flex items-center space-x-2 text-sm text-gray-500 mb-6">
              <.link navigate={~p"/"} class="hover:text-gray-700">Home</.link>
              <span>/</span>
              <.link navigate={~p"/#{@store.slug}"} class="hover:text-gray-700"><%= @store.name %></.link>
              <span>/</span>
              <span class="text-gray-900 font-medium"><%= @category.name %></span>
            </nav>
            
            <h1 class="text-4xl font-bold text-gray-900 mb-4">
              <%= @category.name %>
            </h1>
            
            <%= if @category.description do %>
              <p class="text-xl text-gray-600 mb-8">
                <%= @category.description %>
              </p>
            <% end %>
            
            <div class="text-sm text-gray-500 mb-8">
              <%= length(@products) %> product<%= if length(@products) != 1, do: "s" %> in this category
            </div>
          </div>

          <!-- Products Grid -->
          <%= if Enum.empty?(@products) do %>
            <div class="text-center py-12">
              <div class="text-gray-500 text-lg mb-4">
                No products in this category yet.
              </div>
              <%= if @current_scope && @current_scope.user && @current_scope.user.id == @store.user_id do %>
                <.link
                  navigate={~p"/dashboard/products/new"}
                  class="btn btn-primary"
                >
                  Add Products to This Category
                </.link>
              <% end %>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for product <- @products do %>
                <%= render_product_card(assigns, product) %>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <!-- Store Home Page -->
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
          <!-- Products by Category -->
          <div class="mt-12 space-y-12">
            <!-- Uncategorized Products -->
            <%= if Map.has_key?(@products_by_category, nil) and length(Map.get(@products_by_category, nil)) > 0 do %>
              <div>
                <h2 class="text-2xl font-semibold text-gray-800 mb-6">All Products</h2>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  <%= for product <- Map.get(@products_by_category, nil) do %>
                    <%= render_product_card(assigns, product) %>
                  <% end %>
                </div>
              </div>
            <% end %>
            
            <!-- Products by Custom Category -->
            <%= for category <- @custom_categories do %>
              <%= if Map.has_key?(@products_by_category, category) and length(Map.get(@products_by_category, category)) > 0 do %>
                <div>
                  <div class="flex items-center justify-between mb-6">
                    <h2 class="text-2xl font-semibold text-gray-800">
                      <%= category.name %>
                    </h2>
                    <.link
                      navigate={~p"/#{@store.slug}/#{category.slug}"}
                      class="text-blue-600 hover:text-blue-800 text-sm"
                    >
                      View All (<%= length(Map.get(@products_by_category, category)) %>)
                    </.link>
                  </div>
                  
                  <%= if category.description do %>
                    <p class="text-gray-600 mb-4"><%= category.description %></p>
                  <% end %>
                  
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    <%= for product <- Map.get(@products_by_category, category) do %>
                      <%= render_product_card(assigns, product) %>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_product_card(assigns, product) do
    assigns = assign(assigns, :product, product)
    
    ~H"""
    <div class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow duration-300">
      <!-- Product Image -->
      <div class="h-48 bg-gray-200 overflow-hidden">
        <%= if @product.image_thumb do %>
          <img 
            src={@product.image_thumb} 
            alt={@product.title}
            class="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center text-gray-400">
            <svg class="h-12 w-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
          </div>
        <% end %>
      </div>
      
      <div class="p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-2">
          <.link
            navigate={
              if @product.slug do
                # Only use category route if product actually has a custom category with a slug
                if Map.has_key?(@product, :custom_category) && 
                   @product.custom_category && 
                   Map.has_key?(@product.custom_category, :slug) && 
                   @product.custom_category.slug && 
                   @product.custom_category.slug != "" do
                  ~p"/#{@store.slug}/#{@product.custom_category.slug}/#{@product.slug}"
                else
                  # Use simple store + product route when no category
                  ~p"/#{@store.slug}/#{@product.slug}"
                end
              else
                ~p"/#{@store.slug}/products/#{@product.id}"
              end
            }
            class="hover:text-blue-600 transition-colors duration-200"
          >
            <%= @product.title %>
          </.link>
        </h3>
        
        <%= if @product.description do %>
          <p class="text-gray-600 mb-4 line-clamp-2">
            <%= @product.description %>
          </p>
        <% end %>
        
        <!-- Category Tags -->
        <div class="mb-4 space-y-2">
          <%= if Map.has_key?(@product, :category) && @product.category && Map.has_key?(@product.category, :name) do %>
            <div class="flex items-center space-x-2">
              <span class="text-xs text-gray-500">Platform:</span>
              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                <%= @product.category.name %>
              </span>
            </div>
          <% end %>
          
          <%= if Map.has_key?(@product, :custom_category) && @product.custom_category && Map.has_key?(@product.custom_category, :name) do %>
            <div class="flex items-center space-x-2">
              <span class="text-xs text-gray-500">Store:</span>
              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                <%= @product.custom_category.name %>
              </span>
            </div>
          <% end %>
        </div>
        
        <div class="flex items-center justify-between">
          <div class="text-lg font-bold text-green-600">
            $<%= @product.price %>
          </div>
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
            <%= String.capitalize(@product.type) %>
          </span>
        </div>
      </div>
    </div>
    """
  end
end
