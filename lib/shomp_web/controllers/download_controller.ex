defmodule ShompWeb.DownloadController do
  use ShompWeb, :controller

  alias Shomp.Downloads
  import ShompWeb.UserAuth

  plug :require_authenticated_user

  @doc """
  Shows the download page with product information.
  """
  def show(conn, %{"token" => token}) do
    case Downloads.get_download_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Download link not found or expired.")
        |> redirect(to: ~p"/")

      download ->
        # Verify the current user owns this download
        if download.user_id == conn.assigns.current_scope.user.id do
          conn
          |> assign(:download, download)
          |> render(:show)
        else
          conn
          |> put_flash(:error, "You don't have access to this download.")
          |> redirect(to: ~p"/")
        end
    end
  end

  @doc """
  Processes the actual file download.
  """
  def download(conn, %{"token" => token}) do
    user_id = conn.assigns.current_scope.user.id

    case Downloads.process_download(token, user_id) do
      {:ok, file_url, _download} ->
        # Check if it's an R2 URL or local file
        if String.starts_with?(file_url, "https://") do
          # Generate signed URL for R2 file
          case generate_signed_url(file_url) do
            {:ok, signed_url} ->
              # Instead of redirecting, fetch the file and serve it directly
              # This prevents URL sharing and ensures proper download behavior
              serve_r2_file(conn, signed_url)
            {:error, reason} ->
              conn
              |> put_flash(:error, "Failed to generate download link: #{reason}")
              |> redirect(to: ~p"/")
          end
        else
          # Serve local file securely
          serve_file(conn, file_url)
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Download link not found.")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You don't have access to this download.")
        |> redirect(to: ~p"/")

      {:error, :expired} ->
        conn
        |> put_flash(:error, "This download link has expired.")
        |> redirect(to: ~p"/")

      {:error, :limit_exceeded} ->
        conn
        |> put_flash(:error, "Download limit exceeded for this product.")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "An error occurred while processing your download.")
        |> redirect(to: ~p"/")
    end
  end

  @doc """
  Shows a user's purchased products and download history.
  """
  def purchases(conn, _params) do
    user_id = conn.assigns.current_scope.user.id

    # Get all user universal orders with payment splits and order items loaded
    universal_orders = Shomp.UniversalOrders.list_user_universal_orders(user_id)
    |> Shomp.Repo.preload([:payment_splits, universal_order_items: :product])

    # Manually fetch store data and categories for each product
    orders_with_stores = Enum.map(universal_orders, fn universal_order ->
      order_items_with_stores = Enum.map(universal_order.universal_order_items, fn order_item ->
        store = Shomp.Stores.get_store_by_store_id(order_item.product.store_id)

        # Load platform category if it exists
        product_with_store = %{order_item.product | store: store}
        product_with_categories = if product_with_store.category_id do
          case Shomp.Repo.get(Shomp.Categories.Category, product_with_store.category_id) do
            nil -> product_with_store
            category -> %{product_with_store | category: category}
          end
        else
          product_with_store
        end

        # Load custom category if it exists
        product_with_all = if product_with_categories.custom_category_id do
          case Shomp.Repo.get(Shomp.Categories.Category, product_with_categories.custom_category_id) do
            nil -> product_with_categories
            custom_category -> %{product_with_categories | custom_category: custom_category}
          end
        else
          product_with_categories
        end

        %{order_item | product: product_with_all}
      end)
      %{universal_order | universal_order_items: order_items_with_stores}
    end)

    # Get download stats for digital products
    stats = Downloads.get_user_download_stats(user_id)

    conn
    |> assign(:orders, orders_with_stores)
    |> assign(:stats, stats)
    |> assign(:get_download_token, &get_download_token/2)
    |> render(:purchases)
  end

  # Helper function to get download token for a product and user
  defp get_download_token(product_id, user_id) do
    case Downloads.get_download_by_product_and_user(product_id, user_id) do
      nil -> nil
      download -> download.token
    end
  end

  # Private functions

  defp serve_file(conn, file_path) do
    # Ensure the file path is safe and within allowed directories
    case validate_file_path(file_path) do
      {:ok, safe_path} ->
        # Get file info
        case File.stat(safe_path) do
          {:ok, %{size: size, type: :regular}} ->
            # Set appropriate headers for file download
            conn
            |> put_resp_header("content-disposition", "attachment; filename=#{Path.basename(safe_path)}")
            |> put_resp_header("content-type", get_content_type(safe_path))
            |> put_resp_header("content-length", "#{size}")
            |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
            |> put_resp_header("pragma", "no-cache")
            |> put_resp_header("expires", "0")
            |> send_file(200, safe_path)

          {:error, :enoent} ->
            conn
            |> put_flash(:error, "File not found.")
            |> redirect(to: ~p"/")

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Error accessing file.")
            |> redirect(to: ~p"/")
        end

      {:error, :invalid_path} ->
        conn
        |> put_flash(:error, "Invalid file path.")
        |> redirect(to: ~p"/")
    end
  end

  defp validate_file_path(file_path) do
    # Ensure the file path is within the allowed uploads directory
    # This prevents directory traversal attacks
    uploads_dir = Application.get_env(:shomp, :uploads_dir, "priv/uploads")
    uploads_dir = Path.expand(uploads_dir)

    full_path = Path.expand(file_path)

    if String.starts_with?(full_path, uploads_dir) and File.exists?(full_path) do
      {:ok, full_path}
    else
      {:error, :invalid_path}
    end
  end

  defp get_content_type(file_path) do
    case Path.extname(file_path) do
      ".pdf" -> "application/pdf"
      ".zip" -> "application/zip"
      ".txt" -> "text/plain"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".mp3" -> "audio/mpeg"
      ".mp4" -> "video/mp4"
      ".doc" -> "application/msword"
      ".docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      _ -> "application/octet-stream"
    end
  end

  defp generate_signed_url(r2_url) do
    try do
      IO.puts("=== SIGNED URL GENERATION DEBUG ===")
      IO.puts("R2 URL: #{r2_url}")

      # Parse the R2 URL to extract bucket and key
      # Format: https://endpoint/bucket/key
      case parse_r2_url(r2_url) do
        {:ok, bucket, key} ->
          IO.puts("Parsed - Bucket: #{bucket}, Key: #{key}")

          # Get R2 configuration
          r2_config = Application.get_env(:shomp, :upload)[:r2]
          IO.puts("R2 Config: #{inspect(r2_config)}")

          # Configure ExAws for R2
          config = %{
            access_key_id: r2_config[:access_key_id],
            secret_access_key: r2_config[:secret_access_key],
            region: r2_config[:region] || "auto",
            host: r2_config[:endpoint],
            scheme: "https://"
          }
          IO.puts("ExAws Config: #{inspect(config)}")

          # Generate signed URL valid for 1 hour
          expires_in = 3600 # 1 hour in seconds

          case ExAws.S3.presigned_url(config, :get, bucket, key, expires_in: expires_in) do
            {:ok, signed_url} ->
              IO.puts("✅ Generated signed URL: #{signed_url}")
              {:ok, signed_url}
            {:error, reason} ->
              IO.puts("❌ Failed to generate signed URL: #{inspect(reason)}")
              {:error, "Failed to generate signed URL: #{inspect(reason)}"}
          end
        {:error, reason} ->
          IO.puts("❌ Failed to parse R2 URL: #{reason}")
          {:error, reason}
      end
    rescue
      error ->
        IO.puts("❌ Exception in signed URL generation: #{inspect(error)}")
        {:error, "Failed to generate signed URL: #{inspect(error)}"}
    end
  end

  defp parse_r2_url(r2_url) do
    # Parse URL like: https://endpoint/bucket/key
    case String.split(r2_url, "/") do
      ["https:", "", _endpoint, bucket | key_parts] ->
        key = Enum.join(key_parts, "/")
        {:ok, bucket, key}
      _ ->
        {:error, "Invalid R2 URL format"}
    end
  end

  defp serve_r2_file(conn, signed_url) do
    try do
      IO.puts("=== SERVING R2 FILE DEBUG ===")
      IO.puts("Signed URL: #{signed_url}")

      # Fetch the file from R2 using the signed URL
      case Req.get(signed_url, redirect: true) do
        {:ok, %Req.Response{status: 200, body: body, headers: headers}} ->
          IO.puts("✅ Successfully fetched file from R2")
          IO.puts("Body size: #{byte_size(body)} bytes")
          IO.puts("Headers: #{inspect(headers)}")

          # Extract filename from URL (remove query parameters)
          filename = signed_url
          |> String.split("/")
          |> List.last()
          |> String.split("?")
          |> List.first()
          |> URI.decode()

          IO.puts("Extracted filename: #{filename}")
          IO.puts("Filename type: #{inspect(filename)}")

          # Extract content type from response headers or guess from filename
          content_type = get_content_type_from_headers(headers) || get_content_type(filename)
          IO.puts("Content type: #{content_type}")
          IO.puts("Content type type: #{inspect(content_type)}")

          # Validate values before setting headers
          filename_str = if is_binary(filename), do: filename, else: "download.pdf"
          content_type_str = if is_binary(content_type), do: content_type, else: "application/octet-stream"

          IO.puts("Final filename: #{filename_str}")
          IO.puts("Final content type: #{content_type_str}")

          # Set proper download headers
          conn
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename_str}\"")
          |> put_resp_header("content-type", content_type_str)
          |> put_resp_header("content-length", "#{byte_size(body)}")
          |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
          |> put_resp_header("pragma", "no-cache")
          |> put_resp_header("expires", "0")
          |> send_resp(200, body)

        {:ok, %Req.Response{status: status_code}} ->
          IO.puts("❌ HTTP Error: #{status_code}")
          conn
          |> put_flash(:error, "Failed to download file (HTTP #{status_code})")
          |> redirect(to: ~p"/")

        {:error, reason} ->
          IO.puts("❌ Req Error: #{inspect(reason)}")
          conn
          |> put_flash(:error, "Failed to download file: #{inspect(reason)}")
          |> redirect(to: ~p"/")
      end
    rescue
      error ->
        IO.puts("❌ Exception: #{inspect(error)}")
        conn
        |> put_flash(:error, "Error downloading file: #{inspect(error)}")
        |> redirect(to: ~p"/")
    end
  end

  defp get_content_type_from_headers(headers) do
    case Enum.find(headers, fn {key, _value} -> String.downcase(key) == "content-type" end) do
      {_key, content_type} -> content_type
      nil -> nil
    end
  end
end
