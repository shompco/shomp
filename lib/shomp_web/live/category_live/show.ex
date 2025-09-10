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

      <div class="min-h-screen bg-base-100 py-12">
        <div class="container mx-auto px-4">
          <div class="max-w-6xl mx-auto">
            <!-- Breadcrumbs -->
            <nav class="text-sm breadcrumbs mb-8">
              <ul>
                <li><a href="/" class="link link-hover">Home</a></li>
                <li><a href="/categories" class="link link-hover">Categories</a></li>
                <li><%= @category.name %></li>
              </ul>
            </nav>

            <!-- Category Header -->
            <div class="text-center mb-12">
              <div class="text-6xl mb-4">
                <%= get_category_icon(@category.name) %>
              </div>
              <h1 class="text-4xl md:text-5xl font-bold text-primary mb-4">
                <%= @category.name %>
              </h1>
              <p class="text-xl text-base-content/70">
                <%= @category.description || "Discover amazing products in this category" %>
              </p>
            </div>

            <!-- Products Grid -->
            <%= if Enum.empty?(@products) do %>
              <div class="text-center py-16">
                <div class="text-6xl mb-4">📦</div>
                <h3 class="text-2xl font-semibold mb-4">No Products Yet</h3>
                <p class="text-base-content/70 mb-8">
                  No products have been added to this category yet.
                </p>
                <a href="/stores" class="btn btn-primary btn-lg">
                  Browse All Stores
                </a>
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                <%= for product <- @products do %>
                  <div class="card bg-base-200 shadow-lg hover:shadow-xl transition-all duration-300">
                    <figure class="px-6 pt-6">
                      <%= if product.image_thumb do %>
                        <img src={product.image_thumb} alt={product.title} class="w-full h-48 object-cover rounded-lg" />
                      <% else %>
                        <div class="w-full h-48 bg-gradient-to-br from-primary/20 to-secondary/20 rounded-lg flex items-center justify-center">
                          <span class="text-4xl">
                            <%= case product.type do %>
                              <% "digital" -> %>💻
                              <% "physical" -> %>📦
                              <% _ -> %>🎨
                            <% end %>
                          </span>
                        </div>
                      <% end %>
                    </figure>
                    <div class="card-body">
                      <h3 class="card-title text-lg"><%= product.title %></h3>
                      <p class="text-sm text-base-content/70">
                        <%= if product.description && String.length(product.description) > 0 do %>
                          <%= String.slice(product.description, 0, 100) %><%= if String.length(product.description) > 100, do: "...", else: "" %>
                        <% else %>
                          <%= case product.type do %>
                            <% "digital" -> %>Digital product available for download
                            <% "physical" -> %>Physical product available for purchase
                            <% _ -> %>Product available for purchase
                          <% end %>
                        <% end %>
                      </p>
                      <%= if product.store do %>
                        <p class="text-xs text-base-content/50 mt-2">by <%= product.store.name %></p>
                      <% end %>
                      <div class="flex justify-between items-center mt-4">
                        <span class="text-2xl font-bold text-primary">$<%= product.price %></span>
                        <a href={get_product_url(product)} class="btn btn-primary btn-sm">View Details</a>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>

            <!-- Back to Categories -->
            <div class="text-center mt-12">
              <a href="/categories" class="btn btn-outline btn-lg">
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
          "/stores/#{product.store.slug}/#{product.slug}"
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
end
