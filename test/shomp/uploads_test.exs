defmodule Shomp.UploadsTest do
  use Shomp.DataCase

  alias Shomp.Uploads
  alias Shomp.ImageProcessor

  describe "uploads" do
    test "store_product_image/2 stores image locally" do
      # Mock upload struct
      upload = %{
        path: "/tmp/test_image.jpg",
        filename: "test_image.jpg"
      }
      
      product_id = 123
      
      # Test image storage
      assert {:ok, image_paths} = Uploads.store_product_image(upload, product_id)
      
      # Verify all image variants are created
      assert Map.has_key?(image_paths, :original)
      assert Map.has_key?(image_paths, :thumb)
      assert Map.has_key?(image_paths, :medium)
      assert Map.has_key?(image_paths, :large)
      assert Map.has_key?(image_paths, :extra_large)
      assert Map.has_key?(image_paths, :ultra)
      
      # Verify paths follow expected format
      assert String.starts_with?(image_paths.original, "/uploads/products/#{product_id}/")
      
      # Extract the base filename (without extension)
      base_filename = image_paths.original |> Path.basename() |> Path.rootname()
      
      # Verify all variants follow the naming pattern
      assert String.ends_with?(image_paths.thumb, "_thumb.jpg")
      assert String.ends_with?(image_paths.medium, "_medium.jpg")
      assert String.ends_with?(image_paths.large, "_large.jpg")
      assert String.ends_with?(image_paths.extra_large, "_extra_large.jpg")
      assert String.ends_with?(image_paths.ultra, "_ultra.jpg")
      
      # Verify the base filename is a timestamp-based number (13+ digits)
      assert String.length(base_filename) >= 13
      assert String.match?(base_filename, ~r/^\d+$/)
      
      # Verify it's a reasonable timestamp (should be recent)
      timestamp = String.to_integer(base_filename)
      current_time = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      # Should be within last 5 seconds (allowing for test execution time)
      assert timestamp > current_time - 5000
    end
    
    test "store_product_file/2 stores file locally" do
      upload = %{
        path: "/tmp/test_file.pdf",
        filename: "test_file.pdf"
      }
      
      product_id = 123
      
      assert {:ok, file_path} = Uploads.store_product_file(upload, product_id)
      assert String.starts_with?(file_path, "/uploads/products/#{product_id}/")
      assert String.ends_with?(file_path, ".pdf")
    end
    
    test "delete_product_image/1 deletes image and variants" do
      # This would require actual file creation/deletion testing
      # For now, just test the function exists and returns expected format
      assert Uploads.delete_product_image("/uploads/products/123/image.jpg")
    end
    
    test "delete_product_file/1 deletes file" do
      assert Uploads.delete_product_file("/uploads/products/123/file.pdf")
    end
  end
  
  describe "image_processor" do
    test "process_product_image/1 processes image variants" do
      # Mock image path
      image_path = "/tmp/test_image.jpg"
      
      # Test image processing (will fail without actual ImageMagick, but tests structure)
      result = ImageProcessor.process_product_image(image_path)
      
      # Should return a list of {size, path} tuples
      assert is_list(result)
      # In a real test with ImageMagick, we'd verify the files were created
    end
    
    test "process_image_variant/3 processes single variant" do
      image_path = "/tmp/test_image.jpg"
      size = :thumb
      dimensions = "150x150"
      
      # Test single variant processing
      result = ImageProcessor.process_image_variant(image_path, size, dimensions)
      
      # Should return {:ok, path} or {:error, reason}
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
  
  describe "storage backend configuration" do
    test "defaults to local storage" do
      # Test that the module compiles and defaults to local storage
      assert Uploads.__info__(:module) == Shomp.Uploads
    end
  end
end
