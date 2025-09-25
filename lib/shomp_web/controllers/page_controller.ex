defmodule ShompWeb.PageController do
  use ShompWeb, :controller
  alias Shomp.Categories


  def home(conn, _params) do
    # Load categories with products and thumbnails for the categories section
    categories_with_products = Categories.get_categories_with_products_and_thumbnails()

    # Keep the original categories data for the dropdown
    categories_for_dropdown = Categories.get_categories_with_products()

    render(conn, :home,
      categories: categories_with_products,
      categories_with_products: categories_for_dropdown,
      page_title: "Shomp"
    )
  end

  def serve_upload(conn, %{"path" => path}) do
    # Construct the full file path
    upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
    file_path = Path.join(upload_dir, path)

    IO.puts("=== SERVE UPLOAD DEBUG ===")
    IO.puts("Requested path: #{path}")
    IO.puts("Upload dir: #{upload_dir}")
    IO.puts("Full file path: #{file_path}")
    IO.puts("File exists: #{File.exists?(file_path)}")
    IO.puts("Expanded file path: #{Path.expand(file_path)}")
    IO.puts("Expanded upload dir: #{Path.expand(upload_dir)}")
    IO.puts("Path starts with upload dir: #{String.starts_with?(Path.expand(file_path), Path.expand(upload_dir))}")
    IO.puts("================================")

    # Check if file exists and is within the upload directory
    if File.exists?(file_path) and String.starts_with?(Path.expand(file_path), Path.expand(upload_dir)) do
      # Get file info
      case File.stat(file_path) do
        {:ok, %{size: size, type: :regular}} ->
          # Determine content type
          content_type = get_content_type(file_path)

          # Serve the file
          conn
          |> put_resp_header("content-type", content_type)
          |> put_resp_header("content-length", "#{size}")
          |> put_resp_header("cache-control", "public, max-age=31536000")
          |> send_file(200, file_path)

        {:error, :enoent} ->
          conn
          |> put_status(404)
          |> text("File not found")

        {:error, _reason} ->
          conn
          |> put_status(500)
          |> text("Error accessing file")
      end
    else
      conn
      |> put_status(404)
      |> text("File not found")
    end
  end

  defp get_content_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".svg" -> "image/svg+xml"
      ".pdf" -> "application/pdf"
      ".zip" -> "application/zip"
      ".mp4" -> "video/mp4"
      _ -> "application/octet-stream"
    end
  end

end
