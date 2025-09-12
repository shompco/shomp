defmodule ShompWeb.CategoryLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Categories
  alias Shomp.Products

  def mount(%{"slug" => category_slug}, _session, socket) do
    category = Categories.get_category_by_slug!(category_slug)
    products = Products.get_products_by_category(category.id)

    socket =
      socket
      |> assign(:category, category)
      |> assign(:products, products)
      |> assign(:page_title, "#{category.name} - Browse Products")
      |> assign(:page_description, "#{category.description || "Discover amazing #{String.downcase(category.name)} products from independent creators on Shomp. Zero platform fees, 100% creator earnings."}")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- SEO Meta Tags -->
      <head>
        <title><%= @page_title %></title>
        <meta name="description" content={@page_description} />
        <meta name="keywords" content={"#{@category.name}, #{String.downcase(@category.name)} products, independent creators, zero platform fees, Shomp"} />
        <meta property="og:title" content={@page_title} />
        <meta property="og:description" content={@page_description} />
        <meta property="og:type" content="website" />
        <meta property="og:url" content={"https://shomp.co/categories/#{@category.slug}"} />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content={@page_title} />
        <meta name="twitter:description" content={@page_description} />

        <!-- Structured Data -->
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "CollectionPage",
          "name": "<%= @category.name %>",
          "description": "<%= @page_description %>",
          "url": "https://shomp.co/categories/<%= @category.slug %>",
          "mainEntity": {
            "@type": "ItemList",
            "name": "<%= @category.name %> Products",
            "numberOfItems": <%= length(@products) %>,
            "itemListElement": [
              <%= for {product, index} <- Enum.with_index(@products, 1) do %>
                {
                  "@type": "ListItem",
                  "position": <%= index %>,
                  "item": {
                    "@type": "Product",
                    "name": "<%= product.title %>",
                    "description": "<%= String.slice(product.description || "", 0, 160) %>",
                    "offers": {
                      "@type": "Offer",
                      "price": "<%= product.price %>",
                      "priceCurrency": "USD"
                    }
                  }
                }<%= if index < length(@products), do: "," %>
              <% end %>
            ]
          }
        }
        </script>
      </head>

      <!-- Full viewport width category page -->
      <div class="w-screen min-h-screen bg-base-100" style="margin-left: calc(-50vw + 50%); margin-right: calc(-50vw + 50%); margin-top: -9rem; padding-top: 0;">
        <!-- Ultra Thin Header Section -->
        <div class="relative w-full h-12 bg-gradient-to-r from-primary/10 to-secondary/10">
          <div class="relative z-10 flex items-center justify-between h-full px-4">
            <div class="flex items-center space-x-3">
              <div class="text-xl">
                <%= get_category_icon(@category.name) %>
              </div>
              <h1 class="text-sm font-semibold text-primary">
                <%= @category.name %>
              </h1>
              <span class="text-xs text-base-content/60">
                <%= length(@products) %> products
              </span>
            </div>
            <div class="text-xs text-base-content/70">
              <%= @category.description || "Discover amazing products" %>
            </div>
          </div>
        </div>

        <!-- Breadcrumbs -->
        <div class="w-full bg-base-100">
          <div class="px-4 py-2">
            <nav class="text-xs breadcrumbs">
              <ul>
                <li><a href="/" class="link link-hover">Home</a></li>
                <li><a href="/categories" class="link link-hover">Categories</a></li>
                <li><%= @category.name %></li>
              </ul>
            </nav>
          </div>
        </div>

        <!-- Products Full-Width Grid -->
        <div class="w-full">
          <%= if Enum.empty?(@products) do %>
            <div class="text-center py-24">
              <div class="text-8xl mb-6">📦</div>
              <h3 class="text-3xl font-semibold mb-4">No Products Yet</h3>
              <p class="text-lg text-base-content/70 mb-8 max-w-2xl mx-auto">
                No products have been added to this category yet. Check back soon for amazing products!
              </p>
              <a href="/stores" class="btn btn-primary btn-lg">
                Browse All Stores
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6">
              <%= for {product, index} <- Enum.with_index(@products) do %>
                <a
                  href={get_product_url(product) <> "?referrer=category"}
                  class="group relative aspect-square overflow-hidden bg-base-200 hover:shadow-2xl transition-all duration-500 hover:scale-105"
                  style={"animation-delay: #{index * 50}ms"}
                >
                  <!-- Product Image -->
                  <%= if get_product_image(product) do %>
                    <img
                      src={get_product_image(product)}
                      alt={product.title}
                      class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                      loading="lazy"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-base-200 to-base-300">
                      <div class="text-center p-4">
                        <div class="text-4xl mb-2">
                          <%= case product.type do %>
                            <% "digital" -> %>💻
                            <% "physical" -> %>📦
                            <% _ -> %>🎨
                          <% end %>
                        </div>
                        <p class="text-xs text-base-content/60">No Image</p>
                      </div>
                    </div>
                  <% end %>

                  <!-- Overlay with Product Details -->
                  <div class="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                    <div class="absolute bottom-0 left-0 right-0 p-3 text-white">
                      <h3 class="font-bold text-sm mb-2 line-clamp-2 group-hover:text-primary transition-colors duration-300">
                        <%= product.title %>
                      </h3>
                      <div class="flex items-center justify-between text-xs mb-2">
                        <span class="font-semibold text-primary-200 text-lg">
                          $<%= product.price %>
                        </span>
                        <span class="text-white/80">
                          <%= if product.store, do: product.store.name, else: "Store" %>
                        </span>
                      </div>
                      <div class="flex items-center justify-between">
                        <span class="text-xs text-white/70">
                          <%= case product.type do %>
                            <% "digital" -> %>💻 Digital
                            <% "physical" -> %>📦 Physical
                            <% _ -> %>🎨 Product
                          <% end %>
                        </span>
                        <div class="flex items-center text-xs text-white/70">
                          <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.293l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clip-rule="evenodd" />
                          </svg>
                          View
                        </div>
                      </div>
                      <%= if product.quantity == 0 && product.type == "physical" do %>
                        <div class="mt-2 text-center">
                          <span class="text-xs text-red-300 font-medium bg-red-900/20 px-2 py-1 rounded">SOLD OUT</span>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <!-- Hover Effect Overlay -->
                  <div class="absolute inset-0 bg-gradient-to-br from-white/20 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>
                </a>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Back to Categories -->
        <div class="w-full bg-base-100">
          <div class="px-4 py-4">
            <div class="text-center">
              <a href="/categories" class="btn btn-outline btn-sm">
                ← Back to All Categories
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

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

  defp get_category_icon(category_name) do
    case String.downcase(category_name) do
      "accessories" -> "👜"
      "art & collectibles" -> "🎨"
      "bags & purses" -> "👜"
      "bath & beauty" -> "🧴"
      "clothing" -> "👕"
      "craft supplies & tools" -> "🔧"
      "electronics & accessories" -> "📱"
      "home & living" -> "🏠"
      "jewelry" -> "💍"
      "paper & party supplies" -> "🎉"
      "pet supplies" -> "🐕"
      "shoes" -> "👟"
      "toys & games" -> "🎮"
      "baby" -> "👶"
      "books, movies & music" -> "📚"
      "weddings" -> "💒"
      "gifts" -> "🎁"
      "educational ebooks" -> "📖"
      "templates" -> "📄"
      "online courses" -> "🎓"
      "study guides" -> "📝"
      "memberships/subscriptions" -> "🔐"
      "design assets" -> "🎨"
      "podcasts and audiobooks" -> "🎧"
      "music & audio" -> "🎵"
      "paid newsletters" -> "📰"
      "diy tutorials" -> "🛠️"
      "software/plugins" -> "💻"
      _ -> "📦"
    end
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
end
