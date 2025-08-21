defmodule Shomp.ImageProcessor do
  @moduledoc """
  Handles image processing for product images using Mogrify.
  Creates multiple size variants for performance optimization.
  """
  
  @doc """
  Processes a product image to create multiple size variants.
  Returns a list of {size, path} tuples.
  """
  def process_product_image(image_path) do
    try do
      # Generate thumbnails and different sizes
      sizes = [
        {:thumb, "150x150^"},
        {:medium, "400x400>"},
        {:large, "800x800>"},
        {:extra_large, "1200x1200>"},
        {:ultra, "1600x1600>"}
      ]
      
      Enum.map(sizes, fn {size, geometry} ->
        processed_path = generate_variant_path(image_path, size)
        
        image_path
        |> Mogrify.open()
        |> resize(geometry)
        |> gravity("center")
        |> apply_size_specific_processing(size)
        |> save(path: processed_path)
        
        {size, processed_path}
      end)
    rescue
      error -> 
        # Log error but don't fail the upload
        IO.puts("Image processing failed: #{inspect(error)}")
        []
    end
  end
  
  @doc """
  Processes a single image variant with specific dimensions.
  """
  def process_image_variant(image_path, size, dimensions) do
    try do
      processed_path = generate_variant_path(image_path, size)
      
      image_path
      |> Mogrify.open()
      |> resize(dimensions)
      |> gravity("center")
      |> apply_size_specific_processing(size)
      |> save(path: processed_path)
      
      {:ok, processed_path}
    rescue
      error -> {:error, "Failed to process #{size} variant: #{inspect(error)}"}
    end
  end
  
  # Private functions
  
  defp generate_variant_path(image_path, size) do
    base_name = Path.basename(image_path, Path.extname(image_path))
    ext = Path.extname(image_path)
    dir = Path.dirname(image_path)
    
    Path.join(dir, "#{base_name}_#{size}#{ext}")
  end
  
  defp apply_size_specific_processing(image, :thumb) do
    # For thumbnails, crop to exact dimensions
    image
    |> extent("150x150")
  end
  
  defp apply_size_specific_processing(image, _size) do
    # For other sizes, maintain aspect ratio
    image
  end
  
  defp resize(image, geometry) do
    Mogrify.resize(image, geometry)
  end
  
  defp gravity(image, position) do
    Mogrify.gravity(image, position)
  end
  
  defp extent(image, dimensions) do
    Mogrify.extent(image, dimensions)
  end
  
  defp save(image, opts) do
    Mogrify.save(image, opts)
  end
end
