defmodule ShompWeb.CategoryLive.Index do
  use ShompWeb, :live_view

  alias Shomp.Categories

  def mount(_params, _session, socket) do
    categories_with_products = Categories.get_categories_with_products()

    socket =
      socket
      |> assign(:categories, categories_with_products)
      |> assign(:page_title, "Browse Categories")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-base-100 py-12">
        <div class="container mx-auto px-4">
          <div class="max-w-6xl mx-auto">
            <div class="text-center mb-12">
              <h1 class="text-4xl md:text-5xl font-bold text-primary mb-4">Browse Categories</h1>
              <p class="text-xl text-base-content/70">
                Discover products organized by category
              </p>
            </div>

            <%= if Enum.empty?(@categories) do %>
              <div class="text-center py-16">
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
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                <%= for {category_name, category_slug} <- @categories do %>
                  <div class="card bg-base-200 hover:bg-base-300 transition-all duration-300 hover:shadow-lg">
                    <div class="card-body text-center">
                      <div class="text-4xl mb-4">
                        <%= get_category_icon(category_name) %>
                      </div>
                      <h3 class="card-title justify-center text-lg font-semibold">
                        <%= category_name %>
                      </h3>
                      <div class="card-actions justify-center mt-4">
                        <a href={"/categories/#{category_slug}"} class="btn btn-primary btn-sm">
                          Browse Products
                        </a>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
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
