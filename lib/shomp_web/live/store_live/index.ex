defmodule ShompWeb.StoreLive.Index do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Stores

  @impl true
  def mount(_params, _session, socket) do
    stores = Stores.list_stores_with_users()
    # Manually load products for each store to avoid association issues
    stores_with_products = Enum.map(stores, fn store ->
      products = Shomp.Products.list_products_by_store(store.store_id)
      Map.put(store, :products, products)
    end)
    {:ok, assign(socket, stores: stores_with_products, search: "", filtered_stores: stores_with_products)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    filtered_stores =
      if String.trim(search) == "" do
        socket.assigns.stores
      else
        socket.assigns.stores
        |> Enum.filter(fn store ->
          String.contains?(String.downcase(store.name), String.downcase(search)) or
          String.contains?(String.downcase(store.description || ""), String.downcase(search))
        end)
      end

    {:noreply, assign(socket, search: search, filtered_stores: filtered_stores)}
  end

  # Notification event handlers
  def handle_event("toggle_notifications", _params, socket) do
    show_notifications = !socket.assigns[:show_notifications]
    {:noreply, assign(socket, :show_notifications, show_notifications)}
  end

  def handle_event("mark_notification_read", %{"id" => id}, socket) do
    if socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user
      notification = Shomp.Notifications.get_notification!(id)

      if notification.user_id == user.id do
        case Shomp.Notifications.mark_as_read(notification) do
          {:ok, _notification} ->
            # Refresh notifications and unread count
            unread_count = Shomp.Notifications.unread_count(user.id)
            recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)

            {:noreply,
             socket
             |> assign(:unread_count, unread_count)
             |> assign(:recent_notifications, recent_notifications)}

          {:error, _changeset} ->
            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    if socket.assigns[:current_scope] do
      user = socket.assigns.current_scope.user

      case Shomp.Notifications.mark_all_as_read(user.id) do
        {_count, _} ->
          # Refresh notifications and unread count
          unread_count = Shomp.Notifications.unread_count(user.id)
          recent_notifications = Shomp.Notifications.list_user_notifications(user.id, limit: 5)

          {:noreply,
           socket
           |> assign(:unread_count, unread_count)
           |> assign(:recent_notifications, recent_notifications)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .scrollbar-hide {
        -ms-overflow-style: none;
        scrollbar-width: none;
      }
      .scrollbar-hide::-webkit-scrollbar {
        display: none;
      }
      .smooth-scroll {
        scroll-behavior: smooth;
      }
    </style>
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- Full viewport width stores page -->
      <div class="w-screen min-h-screen bg-base-100" style="margin-left: calc(-50vw + 50%); margin-right: calc(-50vw + 50%); margin-top: -9rem; padding-top: 0;">
        <!-- Ultra Thin Header Section -->
        <div class="relative w-full h-12 bg-gradient-to-r from-primary/10 to-secondary/10">
          <div class="relative z-10 flex items-center justify-between h-full px-4">
            <div class="flex items-center space-x-3">
              <div class="text-xl">
                🏪
              </div>
              <h1 class="text-sm font-semibold text-primary">
                Browse Stores
              </h1>
              <span class="text-xs text-base-content/60">
                <%= length(@stores) %> stores
              </span>
            </div>
            <div class="text-xs text-base-content/70">
              Find amazing products from creators around the world
            </div>
          </div>
        </div>

        <!-- Breadcrumbs -->
        <div class="w-full bg-base-100">
          <div class="px-4 py-2">
            <nav class="text-xs breadcrumbs">
              <ul>
                <li><a href="/" class="link link-hover">Home</a></li>
                <li>Stores</li>
              </ul>
            </nav>
          </div>
        </div>

      <!-- Search Section -->
      <div class="w-full py-4">

        <div class="mb-8 px-4">
          <form phx-change="search" class="max-w-lg mx-auto">
            <div class="relative">
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Search stores by name or description..."
                class="input input-bordered w-full pl-10"
                autocomplete="off"
              />
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
            </div>
          </form>
        </div>
      </div>

      <!-- Stores List - Full viewport width -->
      <div class="w-screen relative left-1/2 -translate-x-1/2">
        <%= if Enum.empty?(@filtered_stores) do %>
          <!-- Empty state - back to constrained container -->
          <div class="w-full px-4">
            <div class="text-center py-12">
              <div class="text-base-content/70 text-lg mb-4">
                <%= if @search == "" do %>
                  No stores found yet. Be the first to create one!
                <% else %>
                  No stores match your search for "<%= @search %>"
                <% end %>
              </div>
              <%= if @current_scope do %>
                <.link
                  navigate={~p"/stores/new"}
                  class="btn btn-primary"
                >
                  Create Your Store
                </.link>
              <% else %>
                <.link
                  navigate={~p"/users/register"}
                  class="btn btn-primary"
                >
                  Join and Create a Store
                </.link>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="space-y-0">
            <%= for store <- @filtered_stores do %>
              <div class="w-full bg-base-100 border-b border-base-300 hover:bg-base-200 transition-colors duration-200">
                <div class="flex items-center justify-between w-full px-4 py-3">
                  <!-- Store Info Section - fixed width -->
                  <div class="flex-shrink-0 w-80 lg:w-96">
                    <.link
                      navigate={~p"/stores/#{store.slug}"}
                      class="text-lg font-semibold text-base-content hover:text-primary transition-colors duration-200 block"
                    >
                      <%= store.name %>
                    </.link>

                    <%= if store.description do %>
                      <p class="text-base-content/70 text-sm mt-1 line-clamp-1">
                        <%= store.description %>
                      </p>
                    <% end %>

                    <div class="flex items-center space-x-3 text-xs text-base-content/60 mt-1">
                      <span class="flex items-center">
                        <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
                        </svg>
                        by <%= store.user.username || "Creator" %>
                      </span>
                      <span class="flex items-center">
                        <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zm0 4a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1V8zm8 0a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1V8zm0 4a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1v-2z" clip-rule="evenodd" />
                        </svg>
                        <%= if store.products, do: length(store.products), else: 0 %> products
                      </span>
                    </div>
                  </div>

                  <!-- Product Images Section - flexible width to fill remaining space -->
                  <div class="flex-1 flex justify-end min-w-0">
                    <%= if store.products && length(store.products) > 0 do %>
                      <div class="flex gap-1 flex-wrap justify-end">
                        <%= for product <- store.products do %>
                          <.link
                            navigate={get_product_url(product)}
                            class="block w-20 h-20 bg-base-200 overflow-hidden hover:shadow-sm transition-all duration-200 hover:scale-105 rounded-lg flex-shrink-0"
                          >
                            <%= if get_product_image(product) do %>
                              <img
                                src={get_product_image(product)}
                                alt={product.title}
                                class="w-full h-full object-cover"
                                loading="lazy"
                              />
                            <% else %>
                              <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-base-200 to-base-300">
                                <div class="text-center p-1">
                                  <svg class="w-5 h-5 text-base-content/40 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                  </svg>
                                </div>
                              </div>
                            <% end %>
                          </.link>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="w-20 h-20 flex items-center justify-center bg-base-200 border border-dashed border-base-300 rounded-lg flex-shrink-0">
                        <div class="text-center">
                          <svg class="w-6 h-6 text-base-content/30 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                          </svg>
                          <p class="text-base-content/40 text-xs mt-1">No products yet</p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Footer sections - back to constrained container -->
      <div class="w-full px-4">
        <%= if @current_scope do %>
          <div class="text-center mt-12">
            <.link
              navigate={~p"/stores/new"}
              class="btn btn-primary btn-lg"
            >
              Create Your Own Store
            </.link>
          </div>
        <% end %>

        <!-- Admin Tools Section -->
        <%= if @current_scope && @current_scope.user && @current_scope.user.role == "admin" do %>
          <div class="mt-16 p-6 bg-error/10 border-2 border-error/20 rounded-lg">
            <h3 class="text-xl font-bold text-error text-center mb-4">🛠️ Admin Tools</h3>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <.link
                navigate={~p"/admin"}
                class="btn btn-error"
              >
                🛠️ Admin Dashboard
              </.link>
              <.link
                navigate={~p"/admin/email-subscriptions"}
                class="btn btn-outline btn-error"
              >
                📧 Email Subscriptions
              </.link>
            </div>
          </div>
        <% end %>
      </div>
      </div>
    </Layouts.app>
    """
  end

  # Helper function to get the best available image for a product
  defp get_product_image(product) do
    cond do
      # Try thumbnail first
      product.image_thumb && product.image_thumb != "" -> product.image_thumb
      # Fall back to original image
      product.image_original && product.image_original != "" -> product.image_original
      # Try medium image
      product.image_medium && product.image_medium != "" -> product.image_medium
      # Try large image
      product.image_large && product.image_large != "" -> product.image_large
      # Try additional images if available
      product.additional_images && length(product.additional_images) > 0 ->
        List.first(product.additional_images)
      # No image available
      true -> nil
    end
  end

  # Helper function to get product URL
  defp get_product_url(product) do
    if product.store do
      if product.slug do
        # Check if custom_category is loaded and has a slug
        custom_category_slug = case product do
          %{custom_category: %Ecto.Association.NotLoaded{}} -> nil
          %{custom_category: nil} -> nil
          %{custom_category: custom_category} when is_map(custom_category) ->
            Map.get(custom_category, :slug)
          _ -> nil
        end

        if custom_category_slug do
          "/stores/#{product.store.slug}/#{custom_category_slug}/#{product.slug}"
        else
          "/stores/#{product.store.slug}/products/#{product.slug}"
        end
      else
        "/stores/#{product.store.slug}/products/#{product.id}"
      end
    else
      "#"
    end
  end
end
