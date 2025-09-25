defmodule Shomp.Uploads do
  @moduledoc """
  Handles file and image uploads for products with support for multiple storage backends.
  Currently supports local volume storage with placeholders for S3 and R2.
  """

  alias Phoenix.PubSub

  # Storage backend will be determined at runtime

  @doc """
  Stores a product image with multiple size variants.
  Returns {:ok, image_paths} or {:error, reason}
  """
  def store_product_image(upload, store_slug) do
    storage_backend = Application.get_env(:shomp, :upload)[:image_storage_backend] || :local
    IO.puts("=== STORE PRODUCT IMAGE DEBUG ===")
    IO.puts("Using storage backend: #{storage_backend}")
    IO.puts("Store slug: #{store_slug}")

    case storage_backend do
      :local -> store_local(upload, store_slug)
      :s3 -> store_s3(upload, store_slug)
      :r2 -> store_r2(upload, store_slug)
    end
  end

  @doc """
  Stores a product file (PDF, ZIP, etc.) for digital products.
  Returns {:ok, file_path} or {:error, reason}
  """
  def store_product_file(upload, product_id) do
    storage_backend = Application.get_env(:shomp, :upload)[:digital_storage_backend] || :r2
    IO.puts("=== STORE PRODUCT FILE DEBUG ===")
    IO.puts("Using storage backend: #{storage_backend}")

    case storage_backend do
      :local -> store_file_local(upload, product_id)
      :s3 -> store_file_s3(upload, product_id)
      :r2 -> store_file_r2(upload, product_id)
    end
  end

  @doc """
  Stores a digital file (PDF, ZIP, MP4) for a product.
  """
  def store_digital_file(upload, product_id) do
    storage_backend = Application.get_env(:shomp, :upload)[:digital_storage_backend] || :r2
    IO.puts("=== STORE DIGITAL FILE DEBUG ===")
    IO.puts("Storage backend: #{inspect(storage_backend)}")
    IO.puts("Upload config: #{inspect(Application.get_env(:shomp, :upload))}")

    case storage_backend do
      :local -> store_file_local(upload, product_id)
      :s3 -> store_file_s3(upload, product_id)
      :r2 -> store_file_r2(upload, product_id)
    end
  end

  @doc """
  Deletes a product image and all its variants.
  """
  def delete_product_image(image_path) do
    storage_backend = Application.get_env(:shomp, :upload)[:image_storage_backend] || :local

    case storage_backend do
      :local -> delete_local_image(image_path)
      :s3 -> delete_s3_image(image_path)
      :r2 -> delete_r2_image(image_path)
    end
  end

  @doc """
  Deletes a product file.
  """
  def delete_product_file(file_path) do
    storage_backend = Application.get_env(:shomp, :upload)[:digital_storage_backend] || :r2

    case storage_backend do
      :local -> delete_local_file(file_path)
      :s3 -> delete_s3_file(file_path)
      :r2 -> delete_r2_file(file_path)
    end
  end

  # Local Storage Implementation

  defp store_local(upload, store_slug) do
    try do
      IO.puts("=== LOCAL STORAGE DEBUG ===")
      IO.puts("Upload structure: #{inspect(upload)}")
      IO.puts("Store slug: #{store_slug}")

      # Create uploads directory structure
      upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
      IO.puts("Upload directory: #{upload_dir}")

      base_dir = Path.join(upload_dir, "products/#{store_slug}")
      IO.puts("Base directory: #{base_dir}")

      # Create directory if it doesn't exist
      File.mkdir_p!(base_dir)
      IO.puts("✅ Directory created/verified")

      # Store original image with clean filename
      filename = generate_filename(upload, store_slug)
      IO.puts("Generated filename: #{filename}")

      original_path = Path.join(base_dir, filename)
      IO.puts("Final file path: #{original_path}")

      # Check if we have content directly or need to read from file
      IO.puts("=== CONTENT CHECK ===")
      IO.puts("Has content key: #{Map.has_key?(upload, :content)}")
      IO.puts("Content exists: #{if Map.has_key?(upload, :content), do: upload.content != nil, else: false}")
      IO.puts("Path exists: #{File.exists?(upload.path)}")

      result = cond do
        # If content is provided directly (from LiveView upload)
        Map.has_key?(upload, :content) && upload.content ->
          IO.puts("✅ Using provided content directly, #{byte_size(upload.content)} bytes")
          File.write!(original_path, upload.content)

          # Verify the file was created
          if File.exists?(original_path) do
            file_size = File.stat!(original_path).size
            IO.puts("✅ File stored successfully, size: #{file_size} bytes")
            {:ok, original_path}
          else
            IO.puts("❌ File was not created at destination")
            {:error, "File was not created at destination"}
          end

        # If file exists at path, read it
        File.exists?(upload.path) ->
          IO.puts("✅ Source file exists: #{upload.path}")
          File.cp!(upload.path, original_path)

          # Verify the file was created
          if File.exists?(original_path) do
            file_size = File.stat!(original_path).size
            IO.puts("✅ File stored successfully, size: #{file_size} bytes")
            {:ok, original_path}
          else
            IO.puts("❌ File was not created at destination")
            {:error, "File was not created at destination"}
          end

        # Otherwise, error
        true ->
          IO.puts("❌ Cannot read file - no content provided and path does not exist")
          IO.puts("Upload structure: #{inspect(upload)}")
          {:error, "File not found and no content provided"}
      end

      case result do
        {:ok, _} ->
          # Broadcast to admin dashboard
          Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:images", %{
            event: "image_uploaded",
            payload: %{
              store_slug: store_slug,
              filename: filename,
              path: "/uploads/products/#{store_slug}/#{filename}"
            }
          })

          # Just return the single image path
          image_url = "/uploads/products/#{store_slug}/#{filename}"
          {:ok, image_url}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, "Failed to store image: #{inspect(error)}"}
    end
  end

  defp store_file_local(upload, product_id) do
    try do
      # Create uploads directory structure
      upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
      base_dir = Path.join(upload_dir, "products/#{product_id}")
      File.mkdir_p!(base_dir)

      # Store file with clean filename
      filename = generate_filename(upload, product_id)
      dest_path = Path.join(base_dir, filename)
      File.cp!(upload.path, dest_path)

      {:ok, "/uploads/products/#{product_id}/#{filename}"}
    rescue
      error -> {:error, "Failed to store file: #{inspect(error)}"}
    end
  end

  defp delete_local_image(image_path) do
    try do
      # Remove /uploads prefix to get actual file path
      relative_path = String.replace(image_path, "/uploads", "")
      upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
      base_path = Path.join(upload_dir, relative_path)

      # Just delete the single image file
      File.rm!(base_path)
      {:ok, :deleted}
    rescue
      error -> {:error, "Failed to delete image: #{inspect(error)}"}
    end
  end

  defp delete_local_file(file_path) do
    try do
      relative_path = String.replace(file_path, "/uploads", "")
      upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
      full_path = Path.join(upload_dir, relative_path)
      File.rm!(full_path)
      {:ok, :deleted}
    rescue
      error -> {:error, "Failed to delete file: #{inspect(error)}"}
    end
  end

  defp generate_filename(upload, store_slug) do
    # Generate a timestamp-based unique ID for each upload
    upload_id = generate_upload_id()

    # Get the original extension and normalize it
    original_ext = Path.extname(upload.filename) |> String.downcase()

    # Convert .jpeg to .jpg
    normalized_ext = case original_ext do
      ".jpeg" -> ".jpg"
      ext -> ext
    end

    # Create filename: storename-timestamp.jpg
    filename = "#{store_slug}-#{upload_id}#{normalized_ext}"

    IO.puts("=== FILENAME GENERATION DEBUG ===")
    IO.puts("Store slug: #{store_slug}")
    IO.puts("Generated filename: #{filename}")
    IO.puts("================================")

    filename
  end

  defp generate_upload_id do
    # Generate a timestamp-based unique ID
    # Format: YYYYMMDDHHMMSSMMM (17 digits)
    # This provides natural ordering and is collision-resistant
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
    |> Integer.to_string()
  end

  # S3 Storage Placeholders (Future Implementation)

  defp store_s3(upload, product_id) do
    # TODO: Implement S3 storage
    # - Upload to S3 bucket
    # - Generate presigned URLs
    # - Handle image variants
    {:error, :s3_not_implemented}
  end

  defp store_file_s3(upload, product_id) do
    # TODO: Implement S3 file storage
    {:error, :s3_not_implemented}
  end

  defp delete_s3_image(image_path) do
    # TODO: Implement S3 image deletion
    {:error, :s3_not_implemented}
  end

  defp delete_s3_file(file_path) do
    # TODO: Implement S3 file deletion
    {:error, :s3_not_implemented}
  end

  # R2 Storage Implementation

  defp store_r2(upload, product_id) do
    try do
      # Get R2 configuration
      r2_config = Application.get_env(:shomp, :upload)[:r2]
      IO.puts("=== R2 IMAGE UPLOAD DEBUG ===")
      IO.puts("R2 config: #{inspect(r2_config)}")
      IO.puts("Upload path: #{upload.path}")
      IO.puts("Upload content_type: #{upload.content_type}")

      # Check if we have content directly or need to read from file
      file_content = cond do
        # If content is provided directly (from LiveView upload)
        Map.has_key?(upload, :content) && upload.content ->
          IO.puts("Using provided content directly")
          upload.content
        # If file exists at path, read it
        File.exists?(upload.path) ->
          IO.puts("Reading file from path: #{upload.path}")
          IO.puts("File size: #{File.stat!(upload.path).size}")
          File.read!(upload.path)
        # Otherwise, error
        true ->
          IO.puts("❌ Cannot read file - no content provided and path does not exist")
          {:error, "File not found and no content provided"}
      end

      case file_content do
        {:error, reason} ->
          {:error, reason}
        content when is_binary(content) ->
          # Generate unique filename
          filename = generate_filename(upload, product_id)
          key = "products/#{product_id}/#{filename}"
          IO.puts("Generated key: #{key}")

          # Configure ExAws for R2
          # For R2, we need to use the endpoint as the host without https://
          endpoint_host = r2_config[:endpoint] |> String.replace("https://", "")
          config = %{
            access_key_id: r2_config[:access_key_id],
            secret_access_key: r2_config[:secret_access_key],
            region: r2_config[:region] || "auto",
            host: endpoint_host,
            scheme: "https://"
          }
          IO.puts("ExAws config: #{inspect(config)}")

          # Upload to R2
          IO.puts("Starting R2 upload...")
          case ExAws.S3.put_object(r2_config[:bucket], key, content,
                                   content_type: upload.content_type) |> ExAws.request(config) do
            {:ok, response} ->
              IO.puts("✅ R2 upload successful: #{inspect(response)}")
              # Generate public URL
              # For R2, the endpoint is already the full domain, so we just need to add the bucket and key
              IO.puts("=== URL CONSTRUCTION DEBUG ===")
              IO.puts("Endpoint: #{inspect(r2_config[:endpoint])}")
              IO.puts("Bucket: #{inspect(r2_config[:bucket])}")
              IO.puts("Key: #{inspect(key)}")
              url = "https://#{r2_config[:endpoint]}/#{r2_config[:bucket]}/#{key}"
              IO.puts("Generated URL: #{url}")
              {:ok, url}
            {:error, reason} ->
              IO.puts("❌ R2 upload failed: #{inspect(reason)}")
              {:error, "Failed to upload to R2: #{inspect(reason)}"}
          end
      end
    rescue
      error ->
        IO.puts("❌ R2 upload exception: #{inspect(error)}")
        {:error, "Failed to store image: #{inspect(error)}"}
    end
  end

  defp store_file_r2(upload, product_id) do
    try do
      # Get R2 configuration
      r2_config = Application.get_env(:shomp, :upload)[:r2]
      IO.puts("=== R2 UPLOAD DEBUG ===")
      IO.puts("R2 config: #{inspect(r2_config)}")
      IO.puts("Upload path: #{upload.path}")
      IO.puts("Upload content_type: #{upload.content_type}")

      # Check if we have content directly or need to read from file
      file_content = cond do
        # If content is provided directly (from LiveView upload)
        Map.has_key?(upload, :content) && upload.content ->
          IO.puts("Using provided content directly")
          upload.content
        # If file exists at path, read it
        File.exists?(upload.path) ->
          IO.puts("Reading file from path: #{upload.path}")
          IO.puts("File size: #{File.stat!(upload.path).size}")
          File.read!(upload.path)
        # Otherwise, error
        true ->
          IO.puts("❌ Cannot read file - no content provided and path does not exist")
          {:error, "File not found and no content provided"}
      end

      case file_content do
        {:error, reason} ->
          {:error, reason}
        content when is_binary(content) ->
          # Generate unique filename
          filename = generate_filename(upload, product_id)
          key = "products/#{product_id}/#{filename}"
          IO.puts("Generated key: #{key}")

          # Configure ExAws for R2
          # For R2, we need to use the endpoint as the host without https://
          endpoint_host = r2_config[:endpoint] |> String.replace("https://", "")
          config = %{
            access_key_id: r2_config[:access_key_id],
            secret_access_key: r2_config[:secret_access_key],
            region: r2_config[:region] || "auto",
            host: endpoint_host,
            scheme: "https://"
          }
          IO.puts("ExAws config: #{inspect(config)}")

          # Upload to R2
          IO.puts("Starting R2 upload...")
          case ExAws.S3.put_object(r2_config[:bucket], key, content,
                                   content_type: upload.content_type) |> ExAws.request(config) do
            {:ok, response} ->
              IO.puts("✅ R2 upload successful: #{inspect(response)}")
              # Generate public URL
              # For R2, the endpoint is already the full domain, so we just need to add the bucket and key
              IO.puts("=== URL CONSTRUCTION DEBUG ===")
              IO.puts("Endpoint: #{inspect(r2_config[:endpoint])}")
              IO.puts("Bucket: #{inspect(r2_config[:bucket])}")
              IO.puts("Key: #{inspect(key)}")
              url = "https://#{r2_config[:endpoint]}/#{r2_config[:bucket]}/#{key}"
              IO.puts("Generated URL: #{url}")
              {:ok, url}
            {:error, reason} ->
              IO.puts("❌ R2 upload failed: #{inspect(reason)}")
              {:error, "Failed to upload to R2: #{inspect(reason)}"}
          end
      end
    rescue
      error ->
        IO.puts("❌ R2 upload exception: #{inspect(error)}")
        {:error, "Failed to store file: #{inspect(error)}"}
    end
  end

  defp delete_r2_image(image_path) do
    try do
      r2_config = Application.get_env(:shomp, :upload)[:r2]
      key = extract_key_from_url(image_path)

      config = %{
        access_key_id: r2_config[:access_key_id],
        secret_access_key: r2_config[:secret_access_key],
        region: r2_config[:region] || "auto",
        host: r2_config[:endpoint]
      }

      case ExAws.S3.delete_object(r2_config[:bucket], key) |> ExAws.request(config) do
        {:ok, _} -> {:ok, :deleted}
        {:error, reason} -> {:error, "Failed to delete from R2: #{inspect(reason)}"}
      end
    rescue
      error -> {:error, "Failed to delete image: #{inspect(error)}"}
    end
  end

  defp delete_r2_file(file_path) do
    try do
      r2_config = Application.get_env(:shomp, :upload)[:r2]
      key = extract_key_from_url(file_path)

      config = %{
        access_key_id: r2_config[:access_key_id],
        secret_access_key: r2_config[:secret_access_key],
        region: r2_config[:region] || "auto",
        host: r2_config[:endpoint]
      }

      case ExAws.S3.delete_object(r2_config[:bucket], key) |> ExAws.request(config) do
        {:ok, _} -> {:ok, :deleted}
        {:error, reason} -> {:error, "Failed to delete from R2: #{inspect(reason)}"}
      end
    rescue
      error -> {:error, "Failed to delete file: #{inspect(error)}"}
    end
  end

  defp extract_key_from_url(url) do
    # Extract the key from R2 URL
    # URL format: https://endpoint/bucket/key
    # We need to remove the protocol, domain, and bucket, keeping only the key
    IO.puts("=== EXTRACT KEY DEBUG ===")
    IO.puts("Input URL: #{inspect(url)}")

    case String.split(url, "/") do
      ["https:", "", _endpoint, _bucket | key_parts] ->
        key = Enum.join(key_parts, "/")
        IO.puts("Extracted key: #{inspect(key)}")
        key
      parts ->
        IO.puts("Failed to parse URL parts: #{inspect(parts)}")
        url  # Fallback to original URL if parsing fails
    end
  end
end
