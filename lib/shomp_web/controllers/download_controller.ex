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
      {:ok, file_path, _download} ->
        # Serve the file securely
        serve_file(conn, file_path)

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
    
    # Get all user orders with products and stores loaded
    orders = Shomp.Orders.list_user_orders(user_id)
    |> Shomp.Repo.preload([order_items: [product: :store]])
    
    # Get download stats for digital products
    stats = Downloads.get_user_download_stats(user_id)

    conn
    |> assign(:orders, orders)
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
end
