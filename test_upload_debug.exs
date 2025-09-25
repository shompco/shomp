#!/usr/bin/env elixir

# Test script to verify upload configuration and directory structure
# Run this with: elixir test_upload_debug.exs

IO.puts("=== UPLOAD CONFIGURATION DEBUG ===")

# Load the application configuration
Application.ensure_all_started(:shomp)

# Check upload configuration
upload_config = Application.get_env(:shomp, :upload)
IO.puts("Upload config: #{inspect(upload_config)}")

# Check storage backends
image_storage_backend = upload_config[:image_storage_backend]
digital_storage_backend = upload_config[:digital_storage_backend]
IO.puts("Image storage backend: #{image_storage_backend}")
IO.puts("Digital storage backend: #{digital_storage_backend}")

# Check local storage directory for images
if image_storage_backend == :local do
  upload_dir = upload_config[:local][:upload_dir]
  IO.puts("Upload directory: #{upload_dir}")

  # Check if directory exists
  if File.exists?(upload_dir) do
    IO.puts("✅ Upload directory exists")

    # Check permissions
    case File.stat(upload_dir) do
      {:ok, stat} ->
        IO.puts("Directory permissions: #{stat.mode}")
        IO.puts("Directory size: #{stat.size}")
      {:error, reason} ->
        IO.puts("❌ Cannot stat directory: #{reason}")
    end
  else
    IO.puts("❌ Upload directory does not exist")
    IO.puts("Attempting to create directory...")

    case File.mkdir_p(upload_dir) do
      :ok ->
        IO.puts("✅ Directory created successfully")
      {:error, reason} ->
        IO.puts("❌ Failed to create directory: #{reason}")
    end
  end

  # Test creating a product directory
  test_product_id = "test-123"
  test_dir = Path.join(upload_dir, "products/#{test_product_id}")
  IO.puts("Test product directory: #{test_dir}")

  case File.mkdir_p(test_dir) do
    :ok ->
      IO.puts("✅ Test product directory created")

      # Clean up
      File.rm_rf(test_dir)
      IO.puts("✅ Test directory cleaned up")
    {:error, reason} ->
      IO.puts("❌ Failed to create test directory: #{reason}")
  end
end

# Check R2 configuration for digital files
if digital_storage_backend == :r2 do
  r2_config = upload_config[:r2]
  IO.puts("R2 config: #{inspect(r2_config)}")

  # Check if R2 environment variables are set
  required_vars = [:bucket, :endpoint, :access_key_id, :secret_access_key]
  missing_vars = Enum.filter(required_vars, fn var ->
    value = r2_config[var]
    is_nil(value) or value == ""
  end)

  if length(missing_vars) == 0 do
    IO.puts("✅ All R2 environment variables are set")
  else
    IO.puts("❌ Missing R2 environment variables: #{inspect(missing_vars)}")
  end
end

IO.puts("=== END DEBUG ===")
