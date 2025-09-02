defmodule ShompWeb.ProductLive.New do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  alias Shomp.Products
  alias Shomp.Stores
  alias Shomp.Categories
  alias Shomp.StoreCategories

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
            phx-change="store_changed"
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

          <!-- Category Selection Section -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium text-gray-900">Product Categories</h3>
            
            <.input
              field={@form[:category_id]}
              type="select"
              label="Platform Category"
              options={@filtered_category_options}
              prompt="Select a platform category"
              required
            />

            <.input
              field={@form[:custom_category_id]}
              type="select"
              label="Store Category (Optional)"
              options={@custom_category_options}
              prompt="Select a store category to organize your products"
            />
            
            <div class="text-sm text-gray-600 bg-blue-50 p-3 rounded-lg">
              <p><strong>Platform Category:</strong> Required. This helps customers discover your product across the platform.</p>
              <p><strong>Store Category:</strong> Optional. Create custom categories in your store settings to organize products your way.</p>
            </div>
          </div>

          <!-- Product Images Upload -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium text-gray-900">Product Images</h3>
            <p class="text-sm text-gray-600">Upload multiple images to showcase your product. The first image will be the primary image.</p>
            
            <.multiple_image_upload_input uploads={@uploads} />
            
            <!-- Image Preview and Reordering -->
            <%= if @uploaded_images && length(@uploaded_images) > 0 do %>
              <div class="space-y-3">
                <h4 class="text-md font-medium text-gray-800">Image Preview & Order</h4>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
                  <%= for {image, index} <- Enum.with_index(@uploaded_images) do %>
                    <div class="relative group">
                      <img 
                        src={image.image_url} 
                        alt="Product image #{index + 1}"
                        class={"w-full h-24 object-cover rounded-lg border-2 transition-all duration-200 #{if index == 0, do: "border-blue-500", else: "border-gray-200"}"}
                      />
                      
                      <!-- Primary Image Badge -->
                      <%= if index == 0 do %>
                        <div class="absolute top-1 left-1 bg-blue-500 text-white text-xs px-2 py-1 rounded-full">
                          Primary
                        </div>
                      <% end %>
                      
                      <!-- Reorder Controls -->
                      <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all duration-200 rounded-lg flex items-center justify-center">
                        <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-200 space-x-1">
                          <%= if index > 0 do %>
                            <button 
                              type="button"
                              phx-click="move_image_up"
                              phx-value-index={index}
                              class="bg-white text-gray-800 p-1 rounded-full hover:bg-gray-100"
                              title="Move up"
                            >
                              ↑
                            </button>
                          <% end %>
                          <%= if index < length(@uploaded_images) - 1 do %>
                            <button 
                              type="button"
                              phx-click="move_image_down"
                              phx-value-index={index}
                              class="bg-white text-gray-800 p-1 rounded-full hover:bg-gray-100"
                              title="Move down"
                            >
                              ↓
                            </button>
                          <% end %>
                        </div>
                      </div>
                      
                      <!-- Remove Button -->
                      <button 
                        type="button"
                        phx-click="remove_image"
                        phx-value-index={index}
                        class="absolute top-1 right-1 bg-red-500 text-white text-xs px-2 py-1 rounded-full hover:bg-red-600 opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                        title="Remove image"
                      >
                        ×
                      </button>
                    </div>
                  <% end %>
                </div>
                <p class="text-xs text-gray-500">Drag images or use arrows to reorder. The first image will be displayed as the primary product image.</p>
              </div>
            <% end %>
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
        
        # Load custom categories for selected store
        custom_categories = if selected_store_id do
          StoreCategories.get_store_category_options_with_default(selected_store_id)
        else
          [{"Select Store First", nil}]
        end
        
        # Configure uploads
        socket = socket
        |> allow_upload(:product_images, 
            accept: ~w(.jpg .jpeg .png .gif .webp),
            max_entries: 10,
            max_file_size: 10_000_000,
            auto_upload: true,
            progress: &handle_progress/3
          )
        
        {:ok, assign_form(socket, changeset, store_options, stores, physical_categories, custom_categories) 
          |> assign(:filtered_category_options, physical_categories)
          |> assign(:uploaded_images, [])}
    end
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      %Products.Product{}
      |> Products.change_product_creation(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset, socket.assigns.store_options, socket.assigns.stores, socket.assigns.filtered_category_options, socket.assigns.custom_category_options)}
  end

  def handle_event("store_changed", %{"product" => %{"store_id" => store_id}}, socket) do
    # Update custom categories when store changes
    custom_categories = if store_id && store_id != "" do
      StoreCategories.get_store_category_options_with_default(store_id)
    else
      [{"Select Store First", nil}]
    end
    
    {:noreply, assign(socket, custom_category_options: custom_categories)}
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

  def handle_event("upload_images", _params, socket) do
    # This event is no longer needed with auto_upload: true
    {:noreply, socket}
  end

  def handle_progress(:product_images, entry, socket) do
    IO.puts("=== UPLOAD PROGRESS ===")
    IO.puts("Entry: #{entry.client_name}")
    IO.puts("Progress: #{entry.progress}%")
    IO.puts("Done: #{entry.done?}")
    IO.puts("Current uploaded_images count: #{length(socket.assigns[:uploaded_images] || [])}")
    
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
        
        # Generate a temporary product ID for storage
        temp_product_id = :crypto.strong_rand_bytes(16) |> Base.encode64()
        
        case Shomp.Uploads.store_product_image(temp_upload, temp_product_id) do
          {:ok, image_url} ->
            IO.puts("Image stored successfully: #{image_url}")
            %{
              image_url: image_url,
              filename: upload_entry.client_name,
              temp_id: temp_product_id
            }
          
          {:error, reason} ->
            IO.puts("Failed to store image: #{inspect(reason)}")
            nil
        end
      else
        nil
      end
    end)
    
    # Filter out failed uploads
    valid_images = Enum.filter(uploaded_files, & &1)
    
    if length(valid_images) > 0 do
      # Add the new images to the existing images
      current_images = socket.assigns.uploaded_images || []
      all_images = current_images ++ valid_images
      
      IO.puts("Auto-uploaded #{length(valid_images)} image(s). Total images: #{length(all_images)}")
      IO.puts("Valid images: #{inspect(valid_images)}")
      IO.puts("All images after update: #{inspect(all_images)}")
      
      {:noreply, 
       socket
       |> put_flash(:info, "Image '#{entry.client_name}' uploaded successfully!")
       |> assign(uploaded_images: all_images)}
    else
      IO.puts("No valid images to add to socket state")
      {:noreply, put_flash(socket, :error, "Failed to process uploaded image")}
    end
  end

  def handle_event("move_image_up", %{"index" => index}, socket) do
    index = String.to_integer(index)
    if index > 0 do
      uploaded_images = socket.assigns.uploaded_images
      new_images = List.insert_at(List.delete_at(uploaded_images, index), index - 1, Enum.at(uploaded_images, index))
      {:noreply, assign(socket, uploaded_images: new_images)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("move_image_down", %{"index" => index}, socket) do
    index = String.to_integer(index)
    uploaded_images = socket.assigns.uploaded_images
    if index < length(uploaded_images) - 1 do
      new_images = List.insert_at(List.delete_at(uploaded_images, index), index + 1, Enum.at(uploaded_images, index))
      {:noreply, assign(socket, uploaded_images: new_images)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_image", %{"index" => index}, socket) do
    index = String.to_integer(index)
    uploaded_images = socket.assigns.uploaded_images
    new_images = List.delete_at(uploaded_images, index)
    {:noreply, assign(socket, uploaded_images: new_images)}
  end

  def handle_event("save", %{"product" => product_params} = params, socket) do
    IO.puts("=== SAVE EVENT TRIGGERED ===")
    IO.puts("Product params: #{inspect(product_params)}")
    IO.puts("Full params: #{inspect(params)}")
    IO.puts("Pre-uploaded files: #{inspect(socket.assigns[:uploaded_files])}")
    IO.puts("Socket assigns keys: #{inspect(Map.keys(socket.assigns))}")
    IO.puts("Uploaded images in socket: #{inspect(socket.assigns[:uploaded_images])}")
    
    # Create the product first
    case Products.create_product(product_params) do
      {:ok, product} ->
        IO.puts("Product created successfully, now processing uploaded files...")
        
        # Use the pre-uploaded images from socket state
        uploaded_images = socket.assigns.uploaded_images || []
        IO.puts("Using pre-uploaded images: #{length(uploaded_images)} images found")
        IO.puts("Uploaded images details: #{inspect(uploaded_images)}")
        
        uploaded_image_data = Enum.map(uploaded_images, fn image ->
          %{
            "image_original" => image.image_url
          }
        end)
        
        # Update product with image paths if any were processed
        case uploaded_image_data do
          [first_image | _] when is_map(first_image) and map_size(first_image) > 0 ->
            # First image becomes the primary image
            primary_image_data = first_image
            
            # Additional images go to additional_images array (image URLs from uploaded_images)
            additional_images = Enum.drop(uploaded_images, 1)
            |> Enum.map(fn img -> img.image_url end)
            
            # Combine primary image with additional images
            final_image_data = Map.put(primary_image_data, "additional_images", additional_images)
            final_image_data = Map.put(final_image_data, "primary_image_index", 0)
            
            IO.puts("Final image data: #{inspect(final_image_data)}")
            IO.puts("Additional images: #{inspect(additional_images)}")
            
            case Products.update_product(product, final_image_data) do
              {:ok, updated_product} ->
                IO.puts("Product updated with multiple images successfully!")
                IO.puts("Updated product additional_images: #{inspect(updated_product.additional_images)}")
                store = Enum.find(socket.assigns.stores, fn s -> s.store_id == product.store_id end)
                
                {:noreply,
                 socket
                 |> put_flash(:info, "Product created with #{length(uploaded_image_data)} images successfully!")
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
        {:noreply, assign_form(socket, changeset, socket.assigns.store_options, socket.assigns.stores, socket.assigns.filtered_category_options, socket.assigns.custom_category_options)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset, store_options, stores, filtered_category_options, custom_category_options) do
    form = to_form(changeset, as: "product")
    assign(socket, 
      form: form, 
      store_options: store_options, 
      stores: stores,
      filtered_category_options: filtered_category_options,
      custom_category_options: custom_category_options,
      uploaded_files: []
    )
  end



end
