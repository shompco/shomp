defmodule ShompWeb.UserLive.Store do
  use ShompWeb, :live_view

  alias Shomp.Accounts
  alias Shomp.Products

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_with_store_and_products(username) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/404")}
      user ->
        {:ok, assign(socket, user: user, products: user.products || [])}
    end
  end

  @impl true
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
                    navigate={get_product_url(product, @user)}
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
  defp get_product_url(product, user) do
    if product.slug do
      "/#{user.username}/#{product.slug}"
    else
      "/#{user.username}/#{product.id}"
    end
  end
end
