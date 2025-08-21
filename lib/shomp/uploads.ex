defmodule Shomp.Uploads do
  @moduledoc """
  Handles file and image uploads for products with support for multiple storage backends.
  Currently supports local volume storage with placeholders for S3 and R2.
  """
  
  @storage_backend Application.compile_env(:shomp, :storage_backend, :local)
  
  @doc """
  Stores a product image with multiple size variants.
  Returns {:ok, image_paths} or {:error, reason}
  """
  def store_product_image(upload, product_id) do
    case @storage_backend do
      :local -> store_local(upload, product_id)
      :s3 -> store_s3(upload, product_id) 
      :r2 -> store_r2(upload, product_id)
    end
  end
  
  @doc """
  Stores a product file (PDF, ZIP, etc.) for digital products.
  Returns {:ok, file_path} or {:error, reason}
  """
  def store_product_file(upload, product_id) do
    case @storage_backend do
      :local -> store_file_local(upload, product_id)
      :s3 -> store_file_s3(upload, product_id)
      :r2 -> store_file_r2(upload, product_id)
    end
  end
  
  @doc """
  Deletes a product image and all its variants.
  """
  def delete_product_image(image_path) do
    case @storage_backend do
      :local -> delete_local_image(image_path)
      :s3 -> delete_s3_image(image_path)
      :r2 -> delete_r2_image(image_path)
    end
  end
  
  @doc """
  Deletes a product file.
  """
  def delete_product_file(file_path) do
    case @storage_backend do
      :local -> delete_local_file(file_path)
      :s3 -> delete_s3_file(file_path)
      :r2 -> delete_r2_file(file_path)
    end
  end
  
  # Local Storage Implementation
  
  defp store_local(upload, product_id) do
    try do
      # Create uploads directory structure
      upload_dir = Application.get_env(:shomp, :upload)[:local][:upload_dir]
      base_dir = Path.join(upload_dir, "products/#{product_id}")
      File.mkdir_p!(base_dir)
      
      # Store original image with clean filename
      filename = generate_filename(upload, product_id)
      original_path = Path.join(base_dir, filename)
      File.cp!(upload.path, original_path)
      
      # Process image to create variants
      variants = Shomp.ImageProcessor.process_product_image(original_path)
      
      # Return paths for all variants
      image_paths = %{
        original: "/uploads/products/#{product_id}/#{filename}",
        thumb: "/uploads/products/#{product_id}/#{filename |> String.replace(".", "_thumb.")}",
        medium: "/uploads/products/#{product_id}/#{filename |> String.replace(".", "_medium.")}",
        large: "/uploads/products/#{product_id}/#{filename |> String.replace(".", "_large.")}",
        extra_large: "/uploads/products/#{product_id}/#{filename |> String.replace(".", "_extra_large.")}",
        ultra: "/uploads/products/#{product_id}/#{filename |> String.replace(".", "_ultra.")}"
      }
      
      {:ok, image_paths}
    rescue
      error -> {:error, "Failed to store image: #{inspect(error)}"}
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
      
      # Delete all variants
      base_name = Path.basename(base_path, Path.extname(base_path))
      ext = Path.extname(base_path)
      dir = Path.dirname(base_path)
      
      # Delete original and all variants
      variants = [
        base_path,
        Path.join(dir, "#{base_name}_thumb#{ext}"),
        Path.join(dir, "#{base_name}_medium#{ext}"),
        Path.join(dir, "#{base_name}_large#{ext}"),
        Path.join(dir, "#{base_name}_extra_large#{ext}"),
        Path.join(dir, "#{base_name}_ultra#{ext}")
      ]
      
      Enum.each(variants, &File.rm/1)
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
  
  defp generate_filename(upload, product_id) do
    # Generate a timestamp-based unique ID for each upload
    upload_id = generate_upload_id()
    ext = Path.extname(upload.filename)
    "#{upload_id}#{ext}"
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
  
  # R2 Storage Placeholders (Future Implementation)
  
  defp store_r2(upload, product_id) do
    # TODO: Implement Cloudflare R2 storage
    # - Upload to R2 bucket
    # - Generate presigned URLs
    # - Handle image variants
    {:error, :r2_not_implemented}
  end
  
  defp store_file_r2(upload, product_id) do
    # TODO: Implement R2 file storage
    {:error, :r2_not_implemented}
  end
  
  defp delete_r2_image(image_path) do
    # TODO: Implement R2 image deletion
    {:error, :r2_not_implemented}
  end
  
  defp delete_r2_file(file_path) do
    # TODO: Implement R2 file deletion
    {:error, :r2_not_implemented}
  end
end
