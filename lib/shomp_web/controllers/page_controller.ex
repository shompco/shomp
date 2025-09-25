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


  def serve_upload(conn, params) do
    IO.puts("=== SERVE UPLOAD DEBUG ===")
    IO.puts("Request URL: #{conn.request_path}")
    IO.puts("All params: #{inspect(params)}")
    IO.puts("Params keys: #{inspect(Map.keys(params))}")

    # Handle the path parameter - it might be a list of path segments
    path = case params do
      %{"path" => path} when is_list(path) ->
        IO.puts("Path is a list: #{inspect(path)}")
        joined = Enum.join(path, "/")
        IO.puts("Joined path: #{joined}")
        joined
      %{"path" => path} when is_binary(path) ->
        IO.puts("Path is a string: #{path}")
        path
      _ ->
        IO.puts("Unexpected params structure: #{inspect(params)}")
        ""
    end

    IO.puts("Final processed path: '#{path}'")
    IO.puts("Path length: #{String.length(path)}")

    # Construct the full file path
    upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
    IO.puts("Upload dir from config: '#{upload_dir}'")

    file_path = Path.join(upload_dir, path)
    IO.puts("Joined file path: '#{file_path}'")

    # Check if file exists
    file_exists = File.exists?(file_path)
    IO.puts("File exists: #{file_exists}")

    if file_exists do
      case File.stat(file_path) do
        {:ok, stat} ->
          IO.puts("File stat: #{inspect(stat)}")
        {:error, reason} ->
          IO.puts("File stat error: #{inspect(reason)}")
      end
    end

    # List directory contents to see what's actually there
    dir_path = Path.dirname(file_path)
    IO.puts("Directory path: '#{dir_path}'")
    IO.puts("Directory exists: #{File.exists?(dir_path)}")

    if File.exists?(dir_path) do
      case File.ls(dir_path) do
        {:ok, files} ->
          IO.puts("Directory contents: #{inspect(files)}")
        {:error, reason} ->
          IO.puts("Directory list error: #{inspect(reason)}")
      end
    end

    # Check parent directory too
    parent_dir = Path.dirname(dir_path)
    IO.puts("Parent directory: '#{parent_dir}'")
    IO.puts("Parent exists: #{File.exists?(parent_dir)}")

    if File.exists?(parent_dir) do
      case File.ls(parent_dir) do
        {:ok, files} ->
          IO.puts("Parent directory contents: #{inspect(files)}")
        {:error, reason} ->
          IO.puts("Parent directory list error: #{inspect(reason)}")
      end
    end

    # Security check
    expanded_file_path = Path.expand(file_path)
    expanded_upload_dir = Path.expand(upload_dir)
    path_starts_with_upload_dir = String.starts_with?(expanded_file_path, expanded_upload_dir)

    IO.puts("Expanded file path: '#{expanded_file_path}'")
    IO.puts("Expanded upload dir: '#{expanded_upload_dir}'")
    IO.puts("Path starts with upload dir: #{path_starts_with_upload_dir}")
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
