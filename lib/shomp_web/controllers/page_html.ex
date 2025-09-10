defmodule ShompWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use ShompWeb, :html

  embed_templates "page_html/*"

  # Helper functions for the home template
  def get_category_icon(category_name) do
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

  def get_category_description(category_name) do
    case String.downcase(category_name) do
      "accessories" -> "Fashion accessories and personal items"
      "art & collectibles" -> "Original artwork and collectible items"
      "bags & purses" -> "Handbags, purses, and carrying accessories"
      "bath & beauty" -> "Personal care and beauty products"
      "clothing" -> "Apparel and fashion items"
      "craft supplies & tools" -> "Materials and tools for crafting"
      "electronics & accessories" -> "Electronic devices and accessories"
      "home & living" -> "Home decor and living essentials"
      "jewelry" -> "Fine jewelry and accessories"
      "paper & party supplies" -> "Stationery and party decorations"
      "pet supplies" -> "Products for your furry friends"
      "shoes" -> "Footwear for every occasion"
      "toys & games" -> "Entertainment and educational toys"
      "baby" -> "Essential items for babies and toddlers"
      "books, movies & music" -> "Media and entertainment content"
      "weddings" -> "Special items for your big day"
      "gifts" -> "Perfect presents for any occasion"
      "educational ebooks" -> "Learning materials and guides"
      "templates" -> "Design templates and layouts"
      "online courses" -> "Educational courses and tutorials"
      "study guides" -> "Academic and test preparation materials"
      "memberships/subscriptions" -> "Exclusive access and content"
      "design assets" -> "Graphics, fonts, and design resources"
      "podcasts and audiobooks" -> "Audio content and entertainment"
      "music & audio" -> "Musical compositions and sound effects"
      "paid newsletters" -> "Premium written content and insights"
      "diy tutorials" -> "Step-by-step instructional content"
      "software/plugins" -> "Digital tools and applications"
      _ -> "Discover amazing products in this category"
    end
  end

  def get_category_sample_products(category_slug, limit) do
    category = Shomp.Categories.get_category_by_slug!(category_slug)
    Shomp.Products.get_products_by_category(category.id, limit)
  end
end
