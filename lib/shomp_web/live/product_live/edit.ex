defmodule ShompWeb.ProductLive.Edit do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Products
  alias Shomp.Categories

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    product = Products.get_product_with_store!(id)
    
    # Check if user owns the store
    if product.store.user_id == user.id do
      changeset = Products.change_product(product)
      
      # Load categories based on current product type
      filtered_category_options = if product.type do
        Categories.get_categories_by_type(product.type)
      else
        []
      end
      
      # Configure uploads
      socket = socket
      |> allow_upload(:product_images, 
          accept: ~w(.jpg .jpeg .png .gif .webp),
          max_entries: 5,
          max_file_size: 10_000_000,
          auto_upload: true
        )
      
      {:ok, assign(socket, 
        product: product, 
        form: to_form(changeset),
        filtered_category_options: filtered_category_options
      )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You can only edit products in your own store")
       |> push_navigate(to: ~p"/#{product.store.slug}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="text-center">
          <.header>
            Edit Product
            <:subtitle>Update your product information</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="product_form" phx-submit="save" phx-change="validate" multipart>
          <.input
            field={@form[:title]}
            type="text"
            label="Product Title"
            required
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
          />

          <.input
            field={@form[:price]}
            type="number"
            label="Price"
            step="0.01"
            min="0.01"
            required
          />

          <.input
            field={@form[:type]}
            type="select"
            label="Product Type"
            options={[
              {"Physical Product", "physical"},
              {"Digital Product", "digital"}
            ]}
            required
            phx-change="type_changed"
          />

          <.input
            field={@form[:category_id]}
            type="select"
            label="Main Category"
            options={@filtered_category_options}
            prompt="Select a main category"
            required
          />

          <!-- Current Product Images -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium text-gray-900">Current Product Images</h3>
            
            <%= if @product.image_original do %>
              <!-- Current Image Display -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-2">
                  <label class="text-sm font-medium text-gray-700">Main Image</label>
                  <div class="relative">
                    <img 
                      src={@product.image_original} 
                      alt="Current main image"
                      class="w-full h-32 object-cover rounded-lg border-2 border-gray-200"
                    />
                    <button
                      type="button"
                      phx-click="remove_image"
                      phx-value-image_type="original"
                      phx-confirm="Remove this image? This action cannot be undone."
                      class="absolute top-2 right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center hover:bg-red-600 transition-colors"
                      title="Remove image"
                    >
                      ×
                    </button>
                  </div>
                </div>
                
                <%= if @product.image_thumb do %>
                  <div class="space-y-2">
                    <label class="text-sm font-medium text-gray-700">Thumbnail</label>
                    <img 
                      src={@product.image_thumb} 
                      alt="Current thumbnail"
                      class="w-full h-32 object-cover rounded-lg border-2 border-gray-200"
                    />
                  </div>
                <% end %>
              </div>
              
              <!-- Image Size Info -->
              <div class="text-sm text-gray-600 bg-gray-50 p-3 rounded-lg">
                <p class="font-medium mb-1">Available Image Sizes:</p>
                <div class="grid grid-cols-2 md:grid-cols-5 gap-2 text-xs">
                  <%= if @product.image_thumb do %>
                    <span class="flex items-center">
                      <span class="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                      Thumb (150×150)
                    </span>
                  <% end %>
                  <%= if @product.image_medium do %>
                    <span class="flex items-center">
                      <span class="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                      Medium (400×400)
                    </span>
                  <% end %>
                  <%= if @product.image_large do %>
                    <span class="flex items-center">
                      <span class="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                      Large (800×800)
                    </span>
                  <% end %>
                  <%= if @product.image_extra_large do %>
                    <span class="flex items-center">
                      <span class="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                      Extra Large (1200×1200)
                    </span>
                  <% end %>
                  <%= if @product.image_ultra do %>
                    <span class="flex items-center">
                      <span class="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                      Ultra (1600×1600)
                    </span>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
                <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <p class="text-gray-500 font-medium">No product images yet</p>
                <p class="text-sm text-gray-400">Upload images below to get started</p>
              </div>
            <% end %>
          </div>

          <!-- Update Product Images -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium text-gray-900">Update Product Images</h3>
            <.image_upload_input uploads={@uploads} />
            
            <!-- DEBUG: Current Image Paths (Remove this after debugging) -->
            <div class="p-3 bg-green-100 border border-green-300 rounded-lg">
              <h4 class="font-semibold text-green-800 mb-2">🔍 DEBUG: Current Image Paths</h4>
              <div class="text-xs text-green-700 space-y-1">
                <div><strong>Original:</strong> <%= @product.image_original || "nil" %></div>
                <div><strong>Thumb:</strong> <%= @product.image_thumb || "nil" %></div>
                <div><strong>Medium:</strong> <%= @product.image_medium || "nil" %></div>
                <div><strong>Large:</strong> <%= @product.image_large || "nil" %></div>
                <div><strong>Extra Large:</strong> <%= @product.image_extra_large || "nil" %></div>
                <div><strong>Ultra:</strong> <%= @product.image_ultra || "nil" %></div>
                <div><strong>Additional Images:</strong> <%= inspect(@product.additional_images) %></div>
                <div><strong>Primary Index:</strong> <%= @product.primary_image_index %></div>
              </div>
            </div>
            
            <p class="text-sm text-gray-600">
              Upload new images to replace the current ones. All image sizes will be automatically generated.
            </p>
          </div>

          <%= if @form[:type].value == "digital" do %>
            <!-- Digital Product File Upload -->
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-gray-900">Digital Product File</h3>
              
              <%= if @product.file_path do %>
                <div class="bg-blue-50 p-3 rounded-lg">
                  <p class="text-sm text-blue-700">
                    <strong>Current file:</strong> <%= @product.file_path %>
                  </p>
                </div>
              <% end %>
              
              <.file_upload_input required={false} />
              <p class="text-sm text-gray-600">
                Upload a new file to replace the current one, or leave empty to keep the existing file.
              </p>
            </div>
          <% end %>

          <div class="flex gap-4">
            <.button phx-disable-with="Saving..." class="btn btn-primary flex-1">
              Save Changes
            </.button>
            
            <.link
              navigate={~p"/#{@product.store.slug}/products/#{@product.id}"}
              class="btn btn-secondary flex-1"
            >
              View Product
            </.link>
          </div>
          
          <div class="mt-6 pt-6 border-t border-base-300">
            <button
              type="button"
              phx-click="delete_product"
              phx-confirm="Are you sure you want to delete this product? This action cannot be undone."
              class="btn btn-error w-full"
            >
              Delete Product
            </button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Products.change_product(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("type_changed", %{"product" => %{"type" => product_type}}, socket) do
    filtered_category_options = if product_type && product_type != "" do
      Categories.get_categories_by_type(product_type)
    else
      # If no type selected, show all categories
      Categories.get_main_category_options()
    end
    
    {:noreply, assign(socket, filtered_category_options: filtered_category_options)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :product_images, ref)}
  end

  def handle_event("save", %{"product" => product_params} = params, socket) do
    IO.puts("=== SAVE EVENT TRIGGERED (EDIT) ===")
    IO.puts("Product params: #{inspect(product_params)}")
    IO.puts("Uploads available: #{inspect(socket.assigns[:uploads])}")
    
    # Process image uploads from LiveView uploads if available
    processed_params = consume_uploaded_entries(socket, :product_images, fn meta, entry ->
      IO.puts("Processing uploaded file: #{entry.client_name}")
      IO.puts("Uploaded to: #{meta.path}")
      
      # Create a temporary upload structure for our existing upload system
      temp_upload = %{
        filename: entry.client_name,
        path: meta.path,
        content_type: entry.client_type
      }
      
      case Shomp.Uploads.store_product_image(temp_upload, socket.assigns.product.id) do
        {:ok, image_paths} ->
          IO.puts("Image processed successfully: #{inspect(image_paths)}")
          
          # Return the image paths to be merged
          %{
            "image_original" => image_paths.original,
            "image_thumb" => image_paths.thumb,
            "image_medium" => image_paths.medium,
            "image_large" => image_paths.large,
            "image_extra_large" => image_paths.extra_large,
            "image_ultra" => image_paths.ultra
          }
        
        {:error, reason} ->
          IO.puts("Image processing failed: #{inspect(reason)}")
          %{}
      end
    end)
    
    # Merge processed image data with product params
    processed_params = case processed_params do
      [first_image | _] when is_map(first_image) ->
        Map.merge(product_params, first_image)
      _ ->
        IO.puts("No image uploads to process")
        product_params
    end
    
    # Process other file uploads
    final_params = process_uploads(params, processed_params, socket.assigns.product.id)
    
    case Products.update_product(socket.assigns.product, final_params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully!")
         |> push_navigate(to: ~p"/#{product.store.slug}/products/#{product.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_product", _params, socket) do
    case Products.delete_product(socket.assigns.product) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted successfully!")
         |> push_navigate(to: ~p"/#{socket.assigns.product.store.slug}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete product. Please try again.")}
    end
  end

  def handle_event("remove_image", %{"image_type" => image_type}, socket) do
    # Remove the specified image type
    case remove_product_image(socket.assigns.product, image_type) do
      {:ok, updated_product} ->
        # Update the socket with the updated product
        socket = assign(socket, product: updated_product)
        
        {:noreply,
         socket
         |> put_flash(:info, "Image removed successfully!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove image: #{reason}")}
    end
  end

  # Get uploaded files from the LiveView uploads
  defp get_uploaded_files(socket) do
    case socket.assigns[:uploads] do
      %{product_images: product_images} ->
        uploaded_files = for entry <- product_images.entries do
          %{
            "filename" => entry.client_name,
            "size" => entry.client_size,
            "type" => entry.client_type,
            "temp_path" => entry.path,
            "uploaded_at" => DateTime.utc_now()
          }
        end
        {:ok, uploaded_files}
      
      _ ->
        # No uploads configured, try to get from form data
        {:ok, []}
    end
  rescue
    _ ->
      {:error, "Failed to get uploaded files"}
  end

  # Process file uploads and return updated product params
  defp process_uploads(params, product_params, product_id) do
    # Process image uploads from LiveView uploads
    image_params = process_image_uploads_from_uploads(product_id)
    
    # Process file uploads for digital products
    file_params = if product_params["type"] == "digital" do
      process_file_uploads(params, product_id)
    else
      %{}
    end
    
    # Merge all processed params
    Map.merge(product_params, Map.merge(image_params, file_params))
  end
  
  defp process_image_uploads_from_uploads(product_id) do
    # This will be called from the save event, so we need to get uploads from the socket
    # For now, return empty params - we'll handle this in the save event
    %{}
  end
  
  defp process_file_uploads(params, product_id) do
    case params do
      %{"product_file" => file} when is_map(file) ->
        case process_digital_file(file, product_id) do
          {:ok, file_path} ->
            %{"file_path" => file_path}
          {:error, _reason} ->
            %{}
        end
      _ ->
        %{}
    end
  end
  
  defp process_single_image(upload, product_id) do
    # Get the first upload from the list
    case List.first(upload) do
      nil -> 
        {:error, "No upload provided"}
      first_upload ->
        # Use the actual product ID for updates
        case Shomp.Uploads.store_product_image(first_upload, product_id) do
          {:ok, image_paths} -> {:ok, image_paths}
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  defp process_digital_file(upload, product_id) do
    # Use the actual product ID for updates
    case Shomp.Uploads.store_product_file(upload, product_id) do
      {:ok, file_path} -> {:ok, file_path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp remove_product_image(product, image_type) do
    # Use the real upload system to delete images
    case image_type do
      "original" ->
        # Delete the original image and all variants
        case Shomp.Uploads.delete_product_image(product.id) do
          {:ok, _} -> 
            # Return the product with image fields cleared
            {:ok, %{product | image_original: nil, image_thumb: nil, image_medium: nil, image_large: nil, image_extra_large: nil, image_ultra: nil}}
          {:error, reason} -> 
            {:error, reason}
        end
      _ ->
        {:ok, product}
    end
  end
end
