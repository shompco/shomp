defmodule ShompWeb.ProductLive.New do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Products
  alias Shomp.Stores
  alias Shomp.Categories

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="text-center">
          <.header>
            Add New Product
            <:subtitle>Create a new product for your store</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="product_form" phx-submit="save" phx-change="validate" multipart>
          <.input
            field={@form[:store_id]}
            type="select"
            label="Select Store"
            options={@store_options}
            required
          />

          <.input
            field={@form[:title]}
            type="text"
            label="Product Title"
            placeholder="Amazing Product"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Describe your product in detail..."
          />

          <.input
            field={@form[:price]}
            type="number"
            label="Price"
            placeholder="9.99"
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
            value="physical"
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

          <!-- Product Images Upload -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium text-gray-900">Product Images</h3>
            <.image_upload_input uploads={@uploads} />
            
            <!-- DEBUG: Upload Status (Remove this after debugging) -->
            <div class="p-3 bg-blue-100 border border-blue-300 rounded-lg">
              <h4 class="font-semibold text-blue-800 mb-2">🔍 DEBUG: Upload Status</h4>
              <div class="text-xs text-blue-700 space-y-1">
                <div><strong>Form Type:</strong> multipart</div>
                <div><strong>Image Input:</strong> <code>input[name="product_images[]"]</code></div>
                <div><strong>File Input:</strong> <code>input[name="product_file"]</code></div>
                <div><strong>Preview Area:</strong> <code>#image-preview</code></div>
                <div><strong>Upload Method:</strong> <span class="font-bold text-green-600">IMMEDIATE</span></div>
                <div><strong>Pre-uploaded Files:</strong> <%= length(@uploaded_files || []) %></div>
                <%= if @uploaded_files && length(@uploaded_files) > 0 do %>
                  <div class="mt-2 p-2 bg-green-50 border border-green-200 rounded">
                    <div class="font-semibold text-green-800">Uploaded Files:</div>
                    <%= for file <- @uploaded_files do %>
                      <div class="text-xs text-green-700">
                        • <%= file["filename"] %> (<%= file["size"] %> bytes, <%= file["type"] %>)
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <%= if @form[:type].value == "digital" do %>
            <!-- Digital Product File Upload -->
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-gray-900">Digital Product File</h3>
              <.file_upload_input required={true} />
            </div>
          <% end %>

          <.button phx-disable-with="Creating product..." class="btn btn-primary w-full">
            Create Product
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # Get the user's stores
    stores = Stores.get_stores_by_user(user.id)
    
    case stores do
      [] ->
        {:ok,
         socket
         |> put_flash(:error, "You need to create a store first!")
         |> push_navigate(to: ~p"/stores/new")}
      
      _ ->
        # Create store options for the dropdown
        store_options = Enum.map(stores, fn store -> 
          {store.name, store.store_id}
        end)
        
        # Pre-select the first store if only one exists
        selected_store_id = if length(stores) == 1, do: List.first(stores).store_id, else: nil
        
        # Default to Physical Product and load physical categories
        changeset = Products.change_product_creation(%Products.Product{})
        changeset = if selected_store_id do
          Ecto.Changeset.put_change(changeset, :store_id, selected_store_id)
        else
          changeset
        end
        changeset = Ecto.Changeset.put_change(changeset, :type, "physical")
        
        # Load physical categories by default
        physical_categories = Categories.get_categories_by_type("physical")
        
        # Configure uploads
        socket = socket
        |> allow_upload(:product_images, 
            accept: ~w(.jpg .jpeg .png .gif .webp),
            max_entries: 5,
            max_file_size: 10_000_000,
            auto_upload: true
          )
        
        {:ok, assign_form(socket, changeset, store_options, stores, physical_categories)}
    end
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      %Products.Product{}
      |> Products.change_product_creation(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset, socket.assigns.store_options, socket.assigns.stores, socket.assigns.filtered_category_options)}
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
    IO.puts("=== SAVE EVENT TRIGGERED ===")
    IO.puts("Product params: #{inspect(product_params)}")
    IO.puts("Full params: #{inspect(params)}")
    IO.puts("Pre-uploaded files: #{inspect(socket.assigns[:uploaded_files])}")
    
    # Create the product first
    case Products.create_product(product_params) do
      {:ok, product} ->
        IO.puts("Product created successfully, now processing uploaded files...")
        
        # Process the uploaded files using consume_uploaded_entries
        uploaded_image_data = consume_uploaded_entries(socket, :product_images, fn meta, entry ->
          IO.puts("Processing uploaded file: #{entry.client_name}")
          IO.puts("Uploaded to: #{meta.path}")
          
          # Create a temporary upload structure for our existing upload system
          temp_upload = %{
            filename: entry.client_name,
            path: meta.path,
            content_type: entry.client_type
          }
          
          case Shomp.Uploads.store_product_image(temp_upload, product.id) do
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
        
        # Update product with image paths if any were processed
        case uploaded_image_data do
          [first_image | _] when is_map(first_image) and map_size(first_image) > 0 ->
            case Products.update_product(product, first_image) do
              {:ok, _updated_product} ->
                IO.puts("Product updated with images successfully!")
                store = Enum.find(socket.assigns.stores, fn s -> s.store_id == product.store_id end)
                
                {:noreply,
                 socket
                 |> put_flash(:info, "Product created with images successfully!")
                 |> push_navigate(to: ~p"/#{store.slug}")}
              
              {:error, changeset} ->
                IO.puts("Failed to update product with images: #{inspect(changeset.errors)}")
                store = Enum.find(socket.assigns.stores, fn s -> s.store_id == product.store_id end)
                
                {:noreply,
                 socket
                 |> put_flash(:warning, "Product created but image update failed")
                 |> push_navigate(to: ~p"/#{store.slug}")}
            end
          
          _ ->
            IO.puts("No images to process, product created without images")
            store = Enum.find(socket.assigns.stores, fn s -> s.store_id == product.store_id end)
            
            {:noreply,
             socket
             |> put_flash(:info, "Product created successfully!")
             |> push_navigate(to: ~p"/#{store.slug}")}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.puts("Product creation failed: #{inspect(changeset.errors)}")
        {:noreply, assign_form(socket, changeset, socket.assigns.store_options, socket.assigns.stores, socket.assigns.filtered_category_options)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset, store_options, stores, filtered_category_options) do
    form = to_form(changeset, as: "product")
    assign(socket, 
      form: form, 
      store_options: store_options, 
      stores: stores,
      filtered_category_options: filtered_category_options
    )
  end



  # Process uploads after product creation
  defp process_uploads_after_creation(params, product) do
    # Process image uploads
    image_params = process_image_uploads_after_creation(params, product.id)
    
    # Process file uploads for digital products
    file_params = if product.type == "digital" do
      process_file_uploads_after_creation(params, product.id)
    else
      %{}
    end
    
    # If we have uploads, update the product
    if map_size(image_params) > 0 or map_size(file_params) > 0 do
      update_params = Map.merge(image_params, file_params)
      case Products.update_product(product, update_params) do
        {:ok, updated_product} -> {:ok, updated_product}
        {:error, changeset} -> {:error, "Failed to update product with uploads: #{inspect(changeset.errors)}"}
      end
    else
      # No uploads to process
      {:ok, product}
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

  # Process pre-uploaded files when creating the product
  defp process_pre_uploaded_files(uploaded_files, product) do
    IO.puts("Processing #{length(uploaded_files)} pre-uploaded files for product #{product.id}")
    
    if length(uploaded_files) > 0 do
      # Process the first image file
                      case List.first(uploaded_files) do
          %{"type" => type} = file ->
            if String.contains?(type, "image") do
              IO.puts("Processing image file: #{file["filename"]}")
              
              # Create a mock upload struct for the existing upload system
              mock_upload = %{
                filename: file["filename"],
                path: file["temp_path"],
                content_type: file["type"]
              }
              
              # Use the existing upload system to process the image
              case Shomp.Uploads.store_product_image(mock_upload, product.id) do
                {:ok, image_paths} ->
                  IO.puts("Image processed successfully: #{inspect(image_paths)}")
                  
                  # Update the product with the image paths
                  update_params = %{
                    "image_original" => image_paths.original,
                    "image_thumb" => image_paths.thumb,
                    "image_medium" => image_paths.medium,
                    "image_large" => image_paths.large,
                    "image_extra_large" => image_paths.extra_large,
                    "image_ultra" => image_paths.ultra
                  }
                  
                  case Products.update_product(product, update_params) do
                    {:ok, updated_product} -> {:ok, updated_product}
                    {:error, changeset} -> {:error, "Failed to update product with image paths: #{inspect(changeset.errors)}"}
                  end
                
                {:error, reason} ->
                  {:error, "Failed to process image: #{reason}"}
              end
            else
              {:ok, product} # Not an image file
            end
          
          _ ->
            {:ok, product} # No files to process
        end
    else
      {:ok, product} # No files to process
    end
  end
  
  defp process_image_uploads_after_creation(params, product_id) do
    case params do
      %{"product_images" => images} when is_list(images) and length(images) > 0 ->
        # Process the first image
        case process_single_image_after_creation(List.first(images), product_id) do
          {:ok, image_paths} ->
            %{
              "image_original" => image_paths.original,
              "image_thumb" => image_paths.thumb,
              "image_medium" => image_paths.medium,
              "image_large" => image_paths.large,
              "image_extra_large" => image_paths.extra_large,
              "image_ultra" => image_paths.ultra
            }
          {:error, _reason} ->
            %{}
        end
      _ ->
        %{}
    end
  end
  
  defp process_file_uploads_after_creation(params, product_id) do
    case params do
      %{"product_file" => file} when is_map(file) ->
        case process_digital_file_after_creation(file, product_id) do
          {:ok, file_path} ->
            %{"file_path" => file_path}
          {:error, _reason} ->
            %{}
        end
      _ ->
        %{}
    end
  end
  
  defp process_single_image_after_creation(upload, product_id) do
    case Shomp.Uploads.store_product_image(upload, product_id) do
      {:ok, image_paths} -> {:ok, image_paths}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp process_digital_file_after_creation(upload, product_id) do
    case Shomp.Uploads.store_product_file(upload, product_id) do
      {:ok, file_path} -> {:ok, file_path}
      {:error, reason} -> {:error, reason}
    end
  end
end
