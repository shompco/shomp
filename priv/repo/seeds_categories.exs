# Seed file for categories
# Run with: mix run priv/repo/seeds_categories.exs

alias Shomp.Repo
alias Shomp.Categories.Category

# Clear existing categories
Repo.delete_all(Category)

# Create root categories (level 0) - these are just organizational
physical_goods = %Category{
  name: "Physical Goods",
  slug: "physical-goods",
  description: "Tangible products that can be shipped",
  level: 0,
  position: 0,
  active: true
} |> Repo.insert!()

digital_goods = %Category{
  name: "Digital Goods",
  slug: "digital-goods", 
  description: "Digital products that can be downloaded",
  level: 0,
  position: 1,
  active: true
} |> Repo.insert!()

# Physical Goods subcategories (level 1) - these are what users actually select from
physical_subcategories = [
  {"Accessories", "accessories", "Fashion and lifestyle accessories", 0},
  {"Art & Collectibles", "art-collectibles", "Original artwork and collectible items", 1},
  {"Bags & Purses", "bags-purses", "Handbags, backpacks, and purses", 2},
  {"Bath & Beauty", "bath-beauty", "Personal care and beauty products", 3},
  {"Clothing", "clothing", "Apparel and fashion items", 4},
  {"Craft Supplies & Tools", "craft-supplies-tools", "Materials and tools for crafting", 5},
  {"Electronics & Accessories", "electronics-accessories", "Electronic devices and accessories", 6},
  {"Home & Living", "home-living", "Home decor and household items", 7},
  {"Jewelry", "jewelry", "Necklaces, rings, earrings, and more", 8},
  {"Paper & Party Supplies", "paper-party-supplies", "Stationery and party decorations", 9},
  {"Pet Supplies", "pet-supplies", "Products for pets and animals", 10},
  {"Shoes", "shoes", "Footwear for all occasions", 11},
  {"Toys & Games", "toys-games", "Entertainment and educational items", 12},
  {"Baby", "baby", "Products for babies and toddlers", 13},
  {"Books, Movies & Music", "books-movies-music", "Physical media and entertainment", 14},
  {"Weddings", "weddings", "Wedding-related products and decorations", 15},
  {"Gifts", "gifts", "Gift items and gift sets", 16}
]

Enum.each(physical_subcategories, fn {name, slug, description, position} ->
  %Category{
    name: name,
    slug: slug,
    description: description,
    parent_id: physical_goods.id,
    level: 1,
    position: position,
    active: true
  } |> Repo.insert!()
end)

# Digital Goods subcategories (level 1) - these are what users actually select from
digital_subcategories = [
  {"Educational eBooks", "educational-ebooks", "Educational books and guides", 0},
  {"Templates", "templates", "Design and document templates", 1},
  {"Online Courses", "online-courses", "Educational courses and tutorials", 2},
  {"Study Guides", "study-guides", "Study materials and guides", 3},
  {"Memberships/Subscriptions", "memberships-subscriptions", "Ongoing access to content", 4},
  {"Design Assets", "design-assets", "Graphics, fonts, and design elements", 5},
  {"Podcasts and Audiobooks", "podcasts-audiobooks", "Audio content and books", 6},
  {"Music & Audio", "music-audio", "Musical compositions and audio files", 7},
  {"Paid Newsletters", "paid-newsletters", "Premium newsletter subscriptions", 8},
  {"DIY Tutorials", "diy-tutorials", "How-to guides and tutorials", 9},
  {"Software/Plugins", "software-plugins", "Software applications and extensions", 10}
]

Enum.each(digital_subcategories, fn {name, slug, description, position} ->
  %Category{
    name: name,
    slug: slug,
    description: description,
    parent_id: digital_goods.id,
    level: 1,
    position: position,
    active: true
  } |> Repo.insert!()
end)

IO.puts("Categories seeded successfully!")
IO.puts("Created #{length(physical_subcategories)} Physical Goods categories")
IO.puts("Created #{length(digital_subcategories)} Digital Goods categories")
IO.puts("Total categories available for selection: #{length(physical_subcategories) + length(digital_subcategories)}")
