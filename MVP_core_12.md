# Shomp MVP Core 12 - Username-as-Store Simplification

## Overview
This MVP keeps the stores table but makes every user have a single default store that's accessed transparently. The UI is simplified so users don't see store management - they just see their products. Username becomes the store identifier for public pages.

## Core Concept
- **One User = One Default Store**: Each user automatically gets a default store
- **Username as Store Identity**: `shomp.co/username` shows the user's default store products
- **Transparent Store Management**: Users never see store creation/management UI
- **Safe Implementation**: Keep existing database structure, just add default store logic
- **Clean URLs**: `shomp.co/username` for store, `shomp.co/username/products/productname` for products

## 1. Database Strategy

### Approach: Keep Stores Table, Add Default Store Logic
We'll keep the existing database structure but add logic to ensure every user has exactly one default store:
- **Keep the `stores` table** and all existing relationships
- **Add `is_default` flag** to mark one store per user as default
- **Auto-create default store** when users register
- **Always access user's default store** transparently

### Database Changes
```elixir
# Migration: Add default store flag
defmodule Shomp.Repo.Migrations.AddDefaultStoreFlag do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :is_default, :boolean, default: false, null: false
    end

    # Ensure only one default store per user
    create unique_index(:stores, [:user_id, :is_default], 
           where: "is_default = true", 
           name: :stores_user_default_unique)
  end
end

# Migration: Mark existing stores as default
defmodule Shomp.Repo.Migrations.MarkExistingStoresAsDefault do
  use Ecto.Migration

  def up do
    # Mark the first store for each user as default
    execute """
    UPDATE stores 
    SET is_default = true 
    WHERE id IN (
      SELECT DISTINCT ON (user_id) id 
      FROM stores 
      ORDER BY user_id, inserted_at ASC
    )
    """
  end

  def down do
    execute "UPDATE stores SET is_default = false"
  end
end
```

### Updated Store Schema
```elixir
defmodule Shomp.Stores.Store do
  schema "stores" do
    # ... existing fields ...
    field :is_default, :boolean, default: false, null: false
    # ... rest of fields ...
  end
end
```

## 2. URL Structure

### New URL Scheme
- **Store/Products**: `shomp.co/username` - Shows user's default store products
- **Product Detail**: `shomp.co/username/product-slug` - Shows specific product
- **Browse Categories**: `shomp.co/categories` - Browse by platform categories
- **Browse Stores**: `shomp.co/stores` - Browse by username (stores)
- **Product Management**: `shomp.co/my/products` - User's product management (replaces "My Stores")
- **Product Creation**: `shomp.co/dashboard/products/new` - Create new product

### Route Updates
```elixir
# In lib/shomp_web/router.ex
scope "/", ShompWeb do
  pipe_through :browser
  
  # Username-based store pages (public) - AFTER all custom shomp routes
  live "/:username", UserLive.Store, :show_by_username
  live "/:username/:product_slug", ProductLive.Show, :show_by_username_product
end

scope "/categories", ShompWeb do
  pipe_through :browser
  
  # Browse platform categories
  live "/", CategoryLive.Index, :index
  live "/:slug", CategoryLive.Show, :show
end

scope "/stores", ShompWeb do
  pipe_through :browser
  
  # Browse stores (usernames)
  live "/", StoreLive.Index, :index
end

scope "/my", ShompWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  # User's product management (replaces My Stores)
  live "/products", UserLive.MyProducts, :index
end

# Remove old store routes:
# - /stores/:store_slug/products/:product_slug
# - /stores/:store_slug/:category_slug/:product_slug
# - /stores/:store_slug/:category_slug
```

## 3. UI Changes

### My Products Page (replaces My Stores)
```elixir
defmodule ShompWeb.UserLive.MyProducts do
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # Load user's products directly
    products = Products.list_user_products(user.id)
    
    {:ok, assign(socket, 
      products: products,
      page_title: "My Products"
    )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8">
        <!-- Header -->
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold text-base-content">My Products</h1>
            <p class="text-base-content/70 mt-2">
              Manage your digital products at shomp.co/<%= @current_scope.user.username %>
            </p>
          </div>
          <div class="flex space-x-3">
            <.link
              navigate={~p"/dashboard/products/new"}
              class="btn btn-primary"
            >
              Add New Product
            </.link>
            <.link
              navigate={~p"/#{@current_scope.user.username}"}
              class="btn btn-outline"
            >
              View My Store
            </.link>
          </div>
        </div>

        <!-- Products Grid -->
        <%= if Enum.empty?(@products) do %>
          <div class="text-center py-16">
            <div class="mx-auto h-24 w-24 text-base-content/30 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-base-content mb-2">No products yet</h3>
            <p class="text-base-content/70 mb-6">Get started by adding your first digital product.</p>
            <.link
              navigate={~p"/dashboard/products/new"}
              class="btn btn-primary"
            >
              Add Your First Product
            </.link>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <%= for product <- @products do %>
              <div class="card bg-base-100 shadow-md border border-base-300 overflow-hidden hover:shadow-lg transition-shadow duration-200">
                <!-- Product Image -->
                <div class="aspect-square bg-base-200 flex items-center justify-center">
                  <%= if get_product_image(product) do %>
                    <img
                      src={get_product_image(product)}
                      alt={product.title}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="text-base-content/40">
                      <svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    </div>
                  <% end %>
                </div>
                
                <!-- Product Info -->
                <div class="card-body p-4">
                  <h3 class="font-semibold text-base-content text-lg mb-2 line-clamp-2">
                    <%= product.title %>
                  </h3>
                  <p class="text-2xl font-bold text-primary mb-3">
                    $<%= product.price %>
                  </p>
                  
                  <!-- Product Stats -->
                  <div class="flex items-center justify-between text-sm text-base-content/60 mb-4">
                    <span class="capitalize"><%= product.type %></span>
                    <span class={if product.quantity == 0 && product.type == "physical", do: "text-error", else: "text-success"}>
                      <%= if product.quantity == 0 && product.type == "physical", do: "Sold Out", else: "Active" %>
                    </span>
                  </div>
                  
                  <!-- Action Buttons -->
                  <div class="flex space-x-2">
                    <.link
                      navigate={~p"/dashboard/products/#{product.id}/edit"}
                      class="btn btn-outline btn-sm flex-1"
                    >
                      Edit
                    </.link>
                    <.link
                      navigate={get_product_url(product)}
                      class="btn btn-primary btn-sm flex-1"
                    >
                      View
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
```

### Username-based Store Page
```elixir
defmodule ShompWeb.UserLive.Store do
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil -> 
        {:ok, push_navigate(socket, to: ~p"/404")}
      user ->
        products = Products.list_user_products(user.id)
        {:ok, assign(socket, user: user, products: products)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8">
        <!-- Store Header -->
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-base-content mb-4">
            <%= @user.username %>'s Store
          </h1>
          <p class="text-lg text-base-content/70">
            Digital products by <%= @user.name || @user.username %>
          </p>
        </div>

        <!-- Products Grid -->
        <%= if Enum.empty?(@products) do %>
          <div class="text-center py-16">
            <div class="mx-auto h-24 w-24 text-base-content/30 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-base-content mb-2">No products yet</h3>
            <p class="text-base-content/70">This store is empty for now.</p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <%= for product <- @products do %>
              <div class="card bg-base-100 shadow-md border border-base-300 overflow-hidden hover:shadow-lg transition-shadow duration-200">
                <!-- Product Image -->
                <div class="aspect-square bg-base-200 flex items-center justify-center">
                  <%= if get_product_image(product) do %>
                    <img
                      src={get_product_image(product)}
                      alt={product.title}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="text-base-content/40">
                      <svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    </div>
                  <% end %>
                </div>
                
                <!-- Product Info -->
                <div class="card-body p-4">
                  <h3 class="font-semibold text-base-content text-lg mb-2 line-clamp-2">
                    <%= product.title %>
                  </h3>
                  <p class="text-2xl font-bold text-primary mb-3">
                    $<%= product.price %>
                  </p>
                  
                  <!-- Product Stats -->
                  <div class="flex items-center justify-between text-sm text-base-content/60 mb-4">
                    <span class="capitalize"><%= product.type %></span>
                    <span class={if product.quantity == 0 && product.type == "physical", do: "text-error", else: "text-success"}>
                      <%= if product.quantity == 0 && product.type == "physical", do: "Sold Out", else: "Available" %>
                    </span>
                  </div>
                  
                  <!-- Action Button -->
                  <.link
                    navigate={get_product_url(product)}
                    class="btn btn-primary w-full"
                  >
                    View Product
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
```

## 4. Context Function Updates

### Update Stores Context
```elixir
defmodule Shomp.Stores do
  @doc """
  Gets or creates the default store for a user.
  This is the main function to use instead of managing multiple stores.
  """
  def get_user_default_store(user) do
    case get_default_store_by_user(user.id) do
      nil -> 
        case ensure_default_store(user) do
          {:ok, store} -> store
          {:error, _} -> nil
        end
      store -> store
    end
  end

  @doc """
  Gets a store by username (for public store pages).
  """
  def get_store_by_username(username) do
    from(s in Store)
    |> join(:inner, [s], u in User, on: s.user_id == u.id)
    |> where([s, u], u.username == ^username and s.is_default == true)
    |> Repo.one()
  end

  @doc """
  Ensures user has a default store. Creates one if it doesn't exist.
  """
  def ensure_default_store(user) do
    case get_default_store_by_user(user.id) do
      nil -> create_default_store(user)
      store -> {:ok, store}
    end
  end

  defp get_default_store_by_user(user_id) do
    from(s in Store, where: s.user_id == ^user_id and s.is_default == true)
    |> Repo.one()
  end

  defp create_default_store(user) do
    store_attrs = %{
      name: user.username || user.name || "My Store",
      slug: user.username,
      description: "Welcome to #{user.username}'s store",
      user_id: user.id,
      is_default: true
    }
    
    create_store(store_attrs)
  end
end
```

### Update Products Context
```elixir
defmodule Shomp.Products do
  @doc """
  Lists products for a user's default store.
  """
  def list_user_products(user) do
    store = Shomp.Stores.get_user_default_store(user)
    if store do
      list_products_by_store(store.store_id)
    else
      []
    end
  end

  @doc """
  Creates a product for a user's default store.
  """
  def create_user_product(user, attrs) do
    store = Shomp.Stores.get_user_default_store(user)
    if store do
      create_product(Map.put(attrs, :store_id, store.store_id))
    else
      {:error, :no_store}
    end
  end

  @doc """
  Gets a product by username and product slug.
  """
  def get_product_by_username_and_slug(username, product_slug) do
    from(p in Product)
    |> join(:inner, [p], s in Store, on: p.store_id == s.store_id)
    |> join(:inner, [p, s], u in User, on: s.user_id == u.id)
    |> where([p, s, u], u.username == ^username and p.slug == ^product_slug)
    |> Repo.one()
  end
end
```

### Update Accounts Context
```elixir
defmodule Shomp.Accounts do
  @doc """
  Gets a user by username.
  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Gets a user by username with their default store and products preloaded.
  """
  def get_user_with_store_and_products(username) do
    from(u in User, where: u.username == ^username)
    |> Repo.one()
    |> case do
      nil -> nil
      user -> 
        store = Shomp.Stores.get_user_default_store(user)
        if store do
          products = Shomp.Products.list_products_by_store(store.store_id)
          %{user | store: store, products: products}
        else
          user
        end
    end
  end
end
```

## 5. Migration Strategy

### Phase 1: Database Migration
1. **Add `is_default` column** to stores table
2. **Mark existing stores as default** (first store per user)
3. **Add unique constraint** to ensure one default store per user
4. **No breaking changes** to existing functionality

### Phase 2: Update Context Functions
1. **Add default store helper functions** to Stores context
2. **Update Products context** to use default store logic
3. **Update Accounts context** with username-based functions
4. **Keep all existing functions** for backward compatibility

### Phase 3: Update UI and Routes
1. **Create new LiveViews** for username-based stores
2. **Update router** with new URL structure
3. **Update navigation** to use new URLs
4. **Hide store management UI** from users

### Phase 4: Auto-Create Default Stores
1. **Update user registration** to auto-create default store with username as slug
2. **Add migration** to create default stores for existing users
3. **Update product creation** to use default store
4. **Remove old store routes** and update all references

## 6. Benefits

### User Experience
- **Simplified**: Username = store, no confusion about multiple stores
- **Clean URLs**: `shomp.co/username` for store, `shomp.co/username/products/productname` for products
- **Focused**: Direct product management without store overhead
- **Intuitive**: Username becomes the store identity

### Technical Benefits
- **Safe Implementation**: No breaking changes to existing functionality
- **Better Performance**: Fewer complex queries, simpler logic
- **Easier Maintenance**: Transparent default store management
- **Backward Compatible**: All existing code continues to work

### Business Benefits
- **Lower Barrier**: Users can start selling immediately
- **Clear Branding**: Username is the store identity
- **Reduced Complexity**: Much simpler for users to understand
- **Better SEO**: Clean, memorable URLs

## 7. Implementation Notes

### URL Structure
- **Store**: `shomp.co/username` - Shows user's default store products
- **Product**: `shomp.co/username/product-slug` - Shows specific product
- **Categories**: `shomp.co/categories` - Browse by platform categories
- **Stores**: `shomp.co/stores` - Browse by username (stores)
- **Product Management**: `shomp.co/my/products` - User's product management (replaces "My Stores")

### What Gets Added
- **Default store logic** - transparent to users
- **Username-based routing** for stores (after custom shomp routes)
- **Simplified product management** interface
- **Auto-store creation** on user registration with username as slug
- **My Products page** showing all products from default store

### What Gets Hidden
- **Store management UI** - users never see it
- **Store creation flows** - automatic
- **Store selection logic** - always uses default
- **Multiple store complexity** - simplified to one per user

### Navigation Changes
- **"My Stores" → "My Products"** in user dropdown menu
- **Route to `/my/products`** instead of `/my/stores`
- **Show user's default store products** in the My Products page
- **Keep platform categories** for browsing (no custom store categories for now)

### What Stays the Same
- **All existing database structure** - no breaking changes
- **All existing context functions** - backward compatible
- **All existing relationships** - products still belong to stores
- **All existing admin functionality** - still works

This approach provides the simplified user experience you want while keeping all existing functionality intact and safe.
