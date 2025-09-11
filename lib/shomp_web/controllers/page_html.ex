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

  def get_japanese_name(category_name) do
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

  def get_product_url(product) do
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

  # Helper function to get the best available image for a product
  def get_product_image(product) do
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
