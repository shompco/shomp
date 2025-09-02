defmodule ShompWeb.KYCImageController do
  use ShompWeb, :controller
  import ShompWeb.UserAuth

  plug :require_authenticated_user
  plug :require_admin_or_owner

  def show(conn, %{"filename" => filename}) do
    # Verify the user has access to this KYC image
    case verify_kyc_image_access(conn.assigns.current_scope.user, filename) do
      {:ok, file_path} ->
        # Serve the file securely
        conn
        |> put_resp_content_type(get_content_type(filename))
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> send_file(200, file_path)
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: ShompWeb.ErrorHTML)
        |> render(:"404")
      
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> put_view(html: ShompWeb.ErrorHTML)
        |> render(:"403")
    end
  end

  defp require_admin_or_owner(conn, _opts) do
    user = conn.assigns.current_scope.user
    
    # Allow admin access
    if user.email == "v1nc3ntpull1ng@gmail.com" do
      conn
    else
      # For non-admins, we'll check ownership in verify_kyc_image_access
      conn
    end
  end

  defp verify_kyc_image_access(user, filename) do
    # Check if user is admin
    if user.email == "v1nc3ntpull1ng@gmail.com" do
      # Admin can access any KYC image
      file_path = Path.join([Application.app_dir(:shomp, "priv/secure_uploads/kyc"), filename])
      if File.exists?(file_path) do
        {:ok, file_path}
      else
        {:error, :not_found}
      end
    else
      # For regular users, check if they own the KYC record
      case find_kyc_by_filename(filename) do
        nil ->
          {:error, :not_found}
        
        kyc_record ->
          # Check if the user owns the store associated with this KYC
          if user_owns_kyc(user, kyc_record) do
            file_path = Path.join([Application.app_dir(:shomp, "priv/secure_uploads/kyc"), filename])
            if File.exists?(file_path) do
              {:ok, file_path}
            else
              {:error, :not_found}
            end
          else
            {:error, :forbidden}
          end
      end
    end
  end

  defp find_kyc_by_filename(filename) do
    # Find KYC record that has this filename in its id_document_path
    import Ecto.Query
    
    from(k in Shomp.Stores.StoreKYC,
      where: like(k.id_document_path, ^"%#{filename}%")
    )
    |> Shomp.Repo.one()
  end

  defp user_owns_kyc(user, kyc_record) do
    # Check if the user owns the store associated with this KYC
    import Ecto.Query
    
    from(s in Shomp.Stores.Store,
      where: s.id == ^kyc_record.store_id and s.user_id == ^user.id
    )
    |> Shomp.Repo.exists?()
  end

  defp get_content_type(filename) do
    case Path.extname(filename) do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".pdf" -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end
end
