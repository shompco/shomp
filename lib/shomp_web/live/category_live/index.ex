defmodule ShompWeb.CategoryLive.Index do
  use ShompWeb, :live_view

  alias Shomp.Categories

  def mount(_params, _session, socket) do
    categories_with_products = Categories.get_categories_with_products_and_thumbnails()

    socket =
      socket
      |> assign(:categories, categories_with_products)
      |> assign(:page_title, "Browse Categories")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
        <!-- Ultra Thin Header Section -->
        <div class="relative w-full h-12 bg-gradient-to-r from-primary/10 to-secondary/10">
          <div class="relative z-10 flex items-center justify-between h-full px-4">
            <div class="flex items-center space-x-3">
              <div class="text-xl">
                📂
              </div>
              <h1 class="text-sm font-semibold text-primary">
                Browse Categories
              </h1>
              <span class="text-xs text-base-content/60">
                <%= length(@categories) %> categories
              </span>
            </div>
            <div class="text-xs text-base-content/70">
              Discover products organized by category
            </div>
          </div>
        </div>

        <!-- Breadcrumbs -->
        <div class="w-full bg-base-100">
          <div class="px-4 py-2">
            <nav class="text-xs breadcrumbs">
              <ul>
                <li><a href="/" class="link link-hover">Home</a></li>
                <li>Categories</li>
              </ul>
            </nav>
          </div>
        </div>

        <%= if Enum.empty?(@categories) do %>
          <div class="w-full text-center py-16">
            <div class="text-6xl mb-4">📂</div>
            <h3 class="text-2xl font-semibold mb-4">No Categories Yet</h3>
            <p class="text-base-content/70 mb-8">
              Categories will appear here once products are added to them.
            </p>
            <a href="/stores" class="btn btn-primary btn-lg">
              Browse Stores
            </a>
          </div>
        <% else %>
          <!-- Categories as full-width rows -->
          <div class="space-y-0">
            <%= for category <- @categories do %>
              <div class="w-screen bg-gradient-to-br from-base-100 via-base-100 to-base-200 border-b border-base-300 hover:from-base-200 hover:via-base-200 hover:to-base-300 transition-all duration-300 relative overflow-hidden group">
                <!-- Lens effect overlay -->
                <div class="absolute inset-0 bg-gradient-to-br from-white/20 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>
                <div class="absolute inset-0 bg-gradient-to-tr from-transparent via-white/10 to-white/30 opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>

                <div class="flex items-center justify-between w-full pr-8 py-6 relative z-10">
                  <!-- Category Info Section - fixed width -->
                  <div class="flex-shrink-0 w-80 lg:w-96 ml-2">
                    <div class="flex items-center space-x-4">
                      <div class="w-12 h-12 bg-gradient-to-br from-primary/20 to-primary/40 rounded-lg flex items-center justify-center shadow-sm">
                        <div class="w-6 h-6 bg-gradient-to-br from-primary to-primary/70 rounded-sm"></div>
                      </div>
                      <div>
                        <a
                          href={"/categories/#{category.slug}"}
                          class="text-2xl font-bold text-base-content group-hover:text-primary transition-colors duration-300 block"
                        >
                          <%= category.name %>
                        </a>
                        <p class="text-primary/80 text-sm font-medium">
                          <%= get_japanese_name(category.name) %>
                        </p>
                        <p class="text-base-content/70 text-sm mt-1">
                          <%= length(category.products) %> products available
                        </p>
                        <a
                          href={"/categories/#{category.slug}"}
                          class="btn btn-primary btn-sm mt-2 shadow-sm hover:shadow-md transition-all duration-300"
                        >
                          Browse <%= category.name %>
                        </a>
                      </div>
                    </div>
                  </div>

                  <!-- Product Images Section - flexible width to fill remaining space -->
                  <div class="flex-1 flex justify-end min-w-0">
                    <%= if category.products && length(category.products) > 0 do %>
                      <div class="flex gap-2 flex-wrap justify-end">
                        <%= for product <- category.products do %>
                          <a
                            href={get_product_url(product)}
                            class="block w-20 h-20 bg-gradient-to-br from-base-200 to-base-300 overflow-hidden hover:shadow-lg transition-all duration-300 hover:scale-105 rounded-lg flex-shrink-0 relative group"
                          >
                            <!-- Lens effect for product thumbnails -->
                            <div class="absolute inset-0 bg-gradient-to-br from-white/30 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>

                            <%= if get_product_image(product) do %>
                              <img
                                src={get_product_image(product)}
                                alt={product.title}
                                class="w-full h-full object-cover relative z-10"
                                loading="lazy"
                              />
                            <% else %>
                              <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-base-200 to-base-300 relative z-10">
                                <div class="text-center p-1">
                                  <svg class="w-5 h-5 text-base-content/40 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                  </svg>
                                </div>
                              </div>
                            <% end %>
                          </a>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="text-base-content/40 text-sm">
                        No products yet
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
    </div>
    <Layouts.flash_group flash={@flash} />
    """
  end

  defp get_japanese_name(category_name) do
    case String.downcase(category_name) do
      "accessories" -> "アクセサリー"
      "art & collectibles" -> "アート・コレクション"
      "bags & purses" -> "バッグ・財布"
      "bath & beauty" -> "バス・美容"
      "clothing" -> "衣類"
      "craft supplies & tools" -> "クラフト用品・工具"
      "electronics & accessories" -> "電子機器・アクセサリー"
      "home & living" -> "ホーム・リビング"
      "jewelry" -> "ジュエリー"
      "paper & party supplies" -> "紙・パーティー用品"
      "pet supplies" -> "ペット用品"
      "shoes" -> "靴"
      "toys & games" -> "おもちゃ・ゲーム"
      "baby" -> "ベビー"
      "books, movies & music" -> "本・映画・音楽"
      "weddings" -> "結婚式"
      "gifts" -> "ギフト"
      "educational ebooks" -> "教育電子書籍"
      "templates" -> "テンプレート"
      "online courses" -> "オンラインコース"
      "study guides" -> "学習ガイド"
      "memberships/subscriptions" -> "メンバーシップ・サブスクリプション"
      "design assets" -> "デザインアセット"
      "podcasts and audiobooks" -> "ポッドキャスト・オーディオブック"
      "music & audio" -> "音楽・オーディオ"
      "paid newsletters" -> "有料ニュースレター"
      "diy tutorials" -> "DIYチュートリアル"
      "software/plugins" -> "ソフトウェア・プラグイン"
      _ -> "その他"
    end
  end

  defp get_product_url(product) do
    if product.store do
      # Get the store owner's username
      store_owner = Shomp.Accounts.get_user_by_id(product.store.user_id)
      if store_owner do
        if product.slug do
          "/#{store_owner.username}/#{product.slug}"
        else
          "/#{store_owner.username}/#{product.id}"
        end
      else
        "#"
      end
    else
      "#"
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
