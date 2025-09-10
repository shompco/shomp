defmodule ShompWeb.SitemapController do
  use ShompWeb, :controller
  alias Shomp.Categories
  alias Shomp.Products
  alias Shomp.Stores

  def sitemap(conn, _params) do
    categories = Categories.get_categories_with_products()
    products = Products.list_products()
    stores = Stores.list_stores()

    sitemap_xml = generate_sitemap_xml(categories, products, stores)

    conn
    |> put_resp_content_type("application/xml")
    |> text(sitemap_xml)
  end

  def robots(conn, _params) do
    robots_txt = """
    User-agent: *
    Allow: /

    Sitemap: #{ShompWeb.Endpoint.url()}/sitemap.xml
    """

    conn
    |> put_resp_content_type("text/plain")
    |> text(robots_txt)
  end

  defp generate_sitemap_xml(categories, products, stores) do
    base_url = ShompWeb.Endpoint.url()

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <!-- Homepage -->
      <url>
        <loc>#{base_url}/</loc>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
      </url>

      <!-- Categories -->
      <url>
        <loc>#{base_url}/categories</loc>
        <changefreq>weekly</changefreq>
        <priority>0.8</priority>
      </url>

      #{for {_name, slug} <- categories do
        """
        <url>
          <loc>#{base_url}/categories/#{slug}</loc>
          <changefreq>weekly</changefreq>
          <priority>0.7</priority>
        </url>
        """
      end}

      <!-- Stores -->
      #{for store <- stores do
        """
        <url>
          <loc>#{base_url}/stores/#{store.slug}</loc>
          <changefreq>weekly</changefreq>
          <priority>0.6</priority>
        </url>
        """
      end}

      <!-- Products -->
      #{for product <- products do
        if product.store do
          product_url = if product.slug do
            if product.custom_category && product.custom_category.slug do
              "#{base_url}/stores/#{product.store.slug}/#{product.custom_category.slug}/#{product.slug}"
            else
              "#{base_url}/stores/#{product.store.slug}/#{product.slug}"
            end
          else
            "#{base_url}/stores/#{product.store.slug}/products/#{product.id}"
          end

          """
          <url>
            <loc>#{product_url}</loc>
            <changefreq>monthly</changefreq>
            <priority>0.5</priority>
          </url>
          """
        end
      end}
    </urlset>
    """
  end
end
