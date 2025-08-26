defmodule ShompWeb.ProductLive.Edit do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Products
  alias Shomp.Categories
  alias Shomp.StoreCategories

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
      
      # Load custom categories for the store
      custom_category_options = StoreCategories.get_store_category_options_with_default(product.store_id)
      
      # Configure uploads with auto upload and progress handler
      socket = socket
      |> allow_upload(:product_images, 
          accept: ~w(.jpg .jpeg .png .gif .webp),
          max_entries: 10,
          max_file_size: 10_000_000,
          auto_upload: true,
          progress: &handle_progress/3
        )
      
      {:ok, assign(socket, 
        product: product, 
        form: to_form(changeset),
        filtered_category_options: filtered_category_options,
        custom_category_options: custom_category_options
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
            phx-change="type_changed"
          />

          <.input
            field={@form[:custom_category_id]}
            type="select"
            label="Store Category (Optional)"
            options={@custom_category_options}
            prompt="Select a store category to organize your products"
          />

          <!-- Product Images Management -->
          <div class="space-y-6">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-medium text-gray-900">Product Images</h3>
              <span class="text-sm text-gray-500">
                <%= if @product.image_thumb do %>
                  <%= 1 + length(@product.additional_images || []) %>
                <% else %>
                  <%= length(@product.additional_images || []) %>
                <% end %> image(s)
              </span>
            </div>
            
            <!-- Current Images Gallery -->
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              <!-- Primary Image -->
              <%= if @product.image_thumb do %>
                <div class="relative group">
                  <img 
                    src={@product.image_thumb} 
                    alt="Primary image"
                    class="w-full h-32 object-cover rounded-lg border-2 border-blue-500 transition-all duration-200"
                  />
                  <div class="absolute top-2 left-2 bg-blue-500 text-white text-xs px-2 py-1 rounded-full">
                    Primary
                  </div>
                  <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all duration-200 rounded-lg flex items-center justify-center">
                    <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-200 space-x-2">
                      <button 
                        type="button"
                        phx-click="remove_image"
                        phx-value-index="primary"
                        phx-confirm="Remove this image? This action cannot be undone."
                        class="bg-red-500 text-white p-2 rounded-full hover:bg-red-600"
                        title="Remove image"
                      >
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
              
              <!-- Additional Images -->
              <%= for {image_url, index} <- Enum.with_index(@product.additional_images || []) do %>
                <div class="relative group">
                  <!-- DEBUG: Show URL -->
                  <div class="text-xs bg-yellow-200 p-1 mb-1">URL: <%= image_url %></div>
                  <img 
                    src={image_url} 
                    alt="Product image #{index + 2}"
                    class="w-full h-32 object-cover rounded-lg border-2 border-gray-200 transition-all duration-200"
                    onerror="this.style.border='3px solid red'; console.log('Failed to load:', this.src);"
                  />
                  <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all duration-200 rounded-lg flex items-center justify-center">
                    <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-200 space-x-2">
                      <button 
                        type="button"
                        phx-click="make_primary"
                        phx-value-index={index}
                        class="bg-blue-500 text-white p-2 rounded-full hover:bg-blue-600"
                        title="Make primary"
                      >
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                        </svg>
                      </button>
                      <button 
                        type="button"
                        phx-click="remove_image"
                        phx-value-index={index}
                        phx-confirm="Remove this image? This action cannot be undone."
                        class="bg-red-500 text-white p-2 rounded-full hover:bg-red-600"
                        title="Remove image"
                      >
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
              
              <!-- Add New Image Card -->
              <%= if (if @product.image_thumb, do: 1, else: 0) + length(@product.additional_images || []) < 10 do %>
                <label class="relative border-2 border-dashed border-gray-300 rounded-lg hover:border-gray-400 transition-colors cursor-pointer">
                  <div class="w-full h-32 flex flex-col items-center justify-center p-4">
                    <svg class="w-8 h-8 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                    </svg>
                    <span class="text-sm text-gray-500 text-center">Click to Add Image</span>
                  </div>
                  <.live_file_input upload={@uploads.product_images} class="hidden" />
                </label>
              <% end %>
            </div>
            
            <!-- Upload Status -->
            <%= if @uploads.product_images.entries != [] do %>
              <div class="bg-blue-50 p-4 rounded-lg">
                <h4 class="text-sm font-medium text-blue-900 mb-2">Upload Progress</h4>
                <%= for entry <- @uploads.product_images.entries do %>
                  <div class="flex items-center justify-between text-sm mb-2">
                    <span class="text-blue-700"><%= entry.client_name %></span>
                    <div class="text-blue-600">
                      <%= cond do %>
                        <% entry.done? -> %> ✓ Uploaded
                        <% entry.progress > 0 -> %> <%= entry.progress %>%
                        <% entry.preflighted? -> %> Starting...
                        <% true -> %> Validating...
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
            
            <!-- No Images State -->
            <%= if !@product.image_thumb and length(@product.additional_images || []) == 0 do %>
              <div class="text-center py-12 border-2 border-dashed border-gray-300 rounded-lg">
                <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                  <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
                <h4 class="text-lg font-medium text-gray-900 mb-2">No images yet</h4>
                <p class="text-gray-500 mb-4">Upload your first product image to get started</p>
                <div class="text-sm text-gray-500">
                  Use the "Click to Add Image" card above to get started
                </div>
              </div>
            <% end %>
            
            <div class="text-sm text-gray-600 bg-gray-50 p-3 rounded-lg">
              <p><strong>Tips:</strong></p>
              <ul class="list-disc list-inside space-y-1 mt-1">
                <li>Upload up to 10 images per product</li>
                <li>Click the star to make any image the primary image</li>
                <li>Images are automatically resized to multiple sizes</li>
                <li>Supported formats: JPG, PNG, GIF, WebP</li>
              </ul>
            </div>
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

  def handle_event("validate", _params, socket) do
    # Handle other validation events (like file uploads)
    IO.puts("=== VALIDATE EVENT ===")
    IO.puts("Upload errors: #{inspect(upload_errors(socket.assigns.uploads.product_images))}")
    
    # Check for upload errors
    errors = upload_errors(socket.assigns.uploads.product_images)
    
    if length(errors) > 0 do
      error_messages = Enum.map(errors, fn
        :too_large -> "File too large (max 10MB)"
        :not_accepted -> "File type not supported (use JPG, PNG, GIF, or WebP)"
        :too_many_files -> "Too many files selected"
        other -> "Upload error: #{other}"
      end)
      
      {:noreply, 
       socket
       |> put_flash(:error, "Upload failed: #{Enum.join(error_messages, ", ")}")}
    else
      {:noreply, socket}
    end
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

  def handle_event("add_image", _params, socket) do
    # This will be triggered when a file is selected
    IO.puts("=== ADD IMAGE EVENT TRIGGERED ===")
    IO.puts("Current uploads: #{inspect(socket.assigns.uploads)}")
    {:noreply, socket}
  end

  def handle_progress(:product_images, entry, socket) do
    IO.puts("=== UPLOAD PROGRESS ===")
    IO.puts("Entry: #{entry.client_name}")
    IO.puts("Progress: #{entry.progress}%")
    IO.puts("Done: #{entry.done?}")
    
    if entry.done? do
      # Process the completed upload immediately
      process_completed_entry(entry, socket)
    else
      {:noreply, socket}
    end
  end

  defp process_completed_entry(entry, socket) do
    IO.puts("Processing completed entry: #{entry.client_name}")
    
    # Use consume_uploaded_entries to get the file path
    uploaded_files = consume_uploaded_entries(socket, :product_images, fn meta, upload_entry ->
      if upload_entry.ref == entry.ref do
        # Create a temporary upload structure
        temp_upload = %{
          filename: upload_entry.client_name,
          path: meta.path,
          content_type: upload_entry.client_type
        }
        
        case Shomp.Uploads.store_product_image(temp_upload, socket.assigns.product.id) do
          {:ok, image_url} ->
            IO.puts("Image stored successfully: #{image_url}")
            image_url
          
          {:error, reason} ->
            IO.puts("Failed to store image: #{inspect(reason)}")
            nil
        end
      else
        nil
      end
    end)
    
    # Filter out failed uploads
    valid_image_urls = Enum.filter(uploaded_files, & &1)
    
    if length(valid_image_urls) > 0 do
      image_url = List.first(valid_image_urls)
      
      # Update the product with the new image
      product = socket.assigns.product
      
              update_params = if product.image_original == nil do
          # Make this the primary image
          %{
            "image_original" => image_url
          }
        else
          # Add to additional images
          current_additional = product.additional_images || []
          %{
            "additional_images" => current_additional ++ [image_url]
          }
        end
      
      case Products.update_product(product, update_params) do
        {:ok, updated_product} ->
          {:noreply, 
           socket
           |> assign(product: updated_product)
           |> put_flash(:info, "Image added successfully!")}
        
        {:error, _changeset} ->
          {:noreply, 
           socket
           |> put_flash(:error, "Failed to save image")}
      end
    else
      {:noreply, 
       socket
       |> put_flash(:error, "Failed to process image")}
    end
  end









  def handle_event("remove_image", %{"index" => "primary"}, socket) do
    product = socket.assigns.product
    
    # Remove primary image by setting image field to nil
    update_params = %{
      "image_original" => nil
    }
    
    case Products.update_product(product, update_params) do
      {:ok, updated_product} ->
        {:noreply, 
         socket
         |> assign(product: updated_product)
         |> put_flash(:info, "Primary image removed successfully")}
      
      {:error, _changeset} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to remove image")}
    end
  end

  def handle_event("remove_image", %{"index" => index}, socket) do
    product = socket.assigns.product
    index = String.to_integer(index)
    
    # Remove image from additional_images array
    current_additional = product.additional_images || []
    updated_additional = List.delete_at(current_additional, index)
    
    case Products.update_product(product, %{"additional_images" => updated_additional}) do
      {:ok, updated_product} ->
        {:noreply, 
         socket
         |> assign(product: updated_product)
         |> put_flash(:info, "Image removed successfully")}
      
      {:error, _changeset} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to remove image")}
    end
  end

  def handle_event("make_primary", %{"index" => index}, socket) do
    product = socket.assigns.product
    index = String.to_integer(index)
    
    additional_images = product.additional_images || []
    
    if index < length(additional_images) do
      # Get the image to make primary
      new_primary_url = Enum.at(additional_images, index)
      
      # Remove from additional images
      updated_additional = List.delete_at(additional_images, index)
      
      # Add current primary to additional images if it exists
      final_additional = if product.image_original do
        [product.image_original | updated_additional]
      else
        updated_additional
      end
      
      # Update the product - Note: We're using the original URL for all sizes
      # In a real app, you'd want to regenerate sizes from the original
      update_params = %{
        "image_original" => new_primary_url,
        "image_thumb" => new_primary_url,
        "image_medium" => new_primary_url,
        "image_large" => new_primary_url,
        "image_extra_large" => new_primary_url,
        "image_ultra" => new_primary_url,
        "additional_images" => final_additional,
        "primary_image_index" => 0
      }
      
      case Products.update_product(product, update_params) do
        {:ok, updated_product} ->
          {:noreply, 
           socket
           |> assign(product: updated_product)
           |> put_flash(:info, "Primary image updated successfully")}
        
        {:error, _changeset} ->
          {:noreply, 
           socket
           |> put_flash(:error, "Failed to update primary image")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("save", %{"product" => product_params} = params, socket) do
    IO.puts("=== SAVE EVENT TRIGGERED (EDIT) ===")
    IO.puts("Product params: #{inspect(product_params)}")
    IO.puts("Uploads available: #{inspect(socket.assigns[:uploads])}")
    
    # Process any new image uploads automatically
    new_image_urls = consume_uploaded_entries(socket, :product_images, fn meta, entry ->
      IO.puts("Processing uploaded file: #{entry.client_name}")
      IO.puts("Uploaded to: #{meta.path}")
      
      # Create a temporary upload structure for our existing upload system
      temp_upload = %{
        filename: entry.client_name,
        path: meta.path,
        content_type: entry.client_type
      }
      
      # Store the image using our upload system
      case Shomp.Uploads.store_product_image(temp_upload, socket.assigns.product.id) do
        {:ok, image_url} ->
          IO.puts("Image stored successfully: #{image_url}")
          image_url  # Return the image URL
        
        {:error, reason} ->
          IO.puts("Failed to store image: #{inspect(reason)}")
          nil
      end
    end)
    
    # Filter out failed uploads
    new_image_urls = Enum.filter(new_image_urls, & &1)
    
    # Prepare final params
    final_params = if length(new_image_urls) > 0 do
      product = socket.assigns.product
      
      if product.image_original == nil do
        # No primary image yet, make the first new image the primary
        first_image_url = List.first(new_image_urls)
        remaining_images = Enum.drop(new_image_urls, 1)
        current_additional = product.additional_images || []
        
        Map.merge(product_params, %{
          "image_original" => first_image_url,
          "additional_images" => current_additional ++ remaining_images
        })
      else
        # Primary image exists, add all new images to additional_images
        current_additional = product.additional_images || []
        Map.merge(product_params, %{
          "additional_images" => current_additional ++ new_image_urls
        })
      end
    else
      product_params
    end
    
    case Products.update_product(socket.assigns.product, final_params) do
      {:ok, product} ->
        flash_message = if length(new_image_urls) > 0 do
          "Product updated successfully with #{length(new_image_urls)} new image(s)!"
        else
          "Product updated successfully!"
        end
        
        {:noreply,
         socket
         |> assign(product: product)  # Update the product in the socket
         |> put_flash(:info, flash_message)}

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

  # Helper function to get all images for a product
  defp get_all_images(product) do
    images = []
    
    # Add primary image if it exists (use thumbnail for display)
    images = if product.image_thumb do
      [product.image_thumb | images]
    else
      images
    end
    
    # Add additional images (these are already thumbnails)
    additional = product.additional_images || []
    images ++ additional
  end
end
