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
            required
            phx-change="type_changed"
          />

          <!-- Digital Product File Upload -->
          <%= if @product_type == "digital" do %>
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-gray-900">Digital Product File</h3>

              <!-- Success Confirmation -->
              <%= if @uploaded_digital_file do %>
                <div class="p-4 bg-green-50 border border-green-200 rounded-lg">
                  <div class="flex items-center space-x-2">
                    <svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                    </svg>
                    <div>
                      <p class="text-sm font-medium text-green-800">
                        File uploaded successfully!
                      </p>
                      <p class="text-xs text-green-600">
                        <%= @uploaded_digital_file.filename %> (<%= @uploaded_digital_file.file_type |> String.upcase() %>)
                      </p>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_digital_file"
                      class="ml-auto text-green-600 hover:text-green-800 text-sm font-medium"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              <% end %>

              <!-- File Upload Input -->
              <%= if !@uploaded_digital_file do %>
                <div class="space-y-2">
                  <label class="block text-sm font-medium text-gray-700">
                    Product File (Required for Digital Products)
                  </label>

                  <div class="flex items-center space-x-4">
                    <.live_file_input
                      upload={@uploads.digital_file}
                      class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                    />
                  </div>

                  <p class="text-xs text-gray-500">
                    Supported formats: PDF, ZIP, MP4 (Max: 300MB)
                  </p>

                  <!-- Upload Progress -->
                  <%= for entry <- @uploads.digital_file.entries do %>
                    <div class="flex items-center space-x-4 p-3 bg-gray-50 rounded-lg border">
                      <div class="flex-1">
                        <div class="flex items-center space-x-2">
                          <div class="w-4 h-4">
                            <%= if entry.progress == 100 do %>
                              <div class="w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
                                <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                                </svg>
                              </div>
                            <% else %>
                              <div class="w-4 h-4 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
                            <% end %>
                          </div>
                          <span class="text-sm font-medium text-gray-900"><%= entry.client_name %></span>
                          <span class="text-xs text-gray-500">(<%= entry.client_size %> bytes)</span>
                        </div>

                        <%= if entry.progress < 100 do %>
                          <div class="mt-2">
                            <div class="w-full bg-gray-200 rounded-full h-2">
                              <div class="bg-blue-600 h-2 rounded-full" style={"width: #{entry.progress}%"}>
                              </div>
                            </div>
                            <div class="text-xs text-gray-500 mt-1">Uploading... <%= entry.progress %>%</div>
                          </div>
                        <% end %>
                      </div>

                      <button
                        type="button"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                        class="text-red-600 hover:text-red-800 text-sm font-medium"
                      >
                        Remove
                      </button>
                    </div>
                  <% end %>

                  <!-- Error Messages -->
                  <%= for {ref, error} <- @uploads.digital_file.errors do %>
                    <div class="mt-2 p-3 bg-red-50 border border-red-200 rounded-lg">
                      <div class="flex items-center space-x-2">
                        <svg class="w-4 h-4 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                        </svg>
                        <span class="text-sm text-red-700"><%= error %></span>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Quantity Available (only for physical products) -->
          <%= if @product_type == "physical" do %>
            <.input
              field={@form[:quantity]}
              type="number"
              label="Quantity Available"
              placeholder="Enter how many items you have in stock"
              min="0"
              step="1"
            />
          <% end %>

          <!-- Shipping Information (only for physical products) -->
          <%= if @product_type == "physical" do %>
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-gray-900">Shipping Information</h3>
              <p class="text-sm text-gray-600">Required for accurate shipping cost calculation</p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input
                  field={@form[:weight]}
                  type="number"
                  label="Weight (lbs)"
                  placeholder="1.0"
                  step="0.1"
                  min="0.1"
                  required
                />

                <.input
                  field={@form[:length]}
                  type="number"
                  label="Length (inches)"
                  placeholder="6.0"
                  step="0.1"
                  min="0.1"
                  required
                />

                <.input
                  field={@form[:width]}
                  type="number"
                  label="Width (inches)"
                  placeholder="4.0"
                  step="0.1"
                  min="0.1"
                  required
                />

                <.input
                  field={@form[:height]}
                  type="number"
                  label="Height (inches)"
                  placeholder="2.0"
                  step="0.1"
                  min="0.1"
                  required
                />
              </div>
            </div>
          <% end %>

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

            <!-- Store Category field hidden per MVP Core 12 -->
            <!--
            <.input
              field={@form[:custom_category_id]}
              type="select"
              label="Store Category (Optional)"
              options={@custom_category_options}
              prompt="Select a store category to organize your products"
            />
            -->

            <div class="text-sm text-gray-600 bg-blue-50 p-3 rounded-lg">
              <p><strong>Platform Category:</strong> Required. This helps customers discover your product across the platform.</p>
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

          <!-- US Citizen Compliance Checkbox -->
          <div class="space-y-4">
            <div class="space-y-2">
              <div class="fieldset mb-2">
                <label>
                  <input type="hidden" name="product[us_citizen_confirmation]" value="false" />
                  <span class="label">
                    <input
                      type="checkbox"
                      id="product_us_citizen_confirmation"
                      name="product[us_citizen_confirmation]"
                      value="true"
                      checked={@form[:us_citizen_confirmation].value}
                      class="checkbox checkbox-sm"
                      required
                    />
                    I confirm that I am located in the United States and eligible to receive payments here.
                  </span>
                </label>
                <%= if @form[:us_citizen_confirmation].errors != [] do %>
                  <p class="mt-1.5 flex gap-2 items-center text-sm text-orange-600">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                    Shomp is only available to users based in the U.S. This ensures we can process payouts smoothly.
                  </p>
                <% end %>
              </div>
            </div>
          </div>

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

    # Get or create the user's default store
    store = Stores.get_user_default_store(user)

    if store do
      # Default to Physical Product and load physical categories
      changeset = Products.change_product_creation(%Products.Product{})
      changeset = Ecto.Changeset.put_change(changeset, :store_id, store.store_id)
      changeset = Ecto.Changeset.put_change(changeset, :type, "physical")
      changeset = Ecto.Changeset.put_change(changeset, :us_citizen_confirmation, false)
      changeset = Ecto.Changeset.put_change(changeset, :quantity, 1)

        # Load physical categories by default
        physical_categories = Categories.get_categories_by_type("physical")

        # Load custom categories for the default store
        custom_categories = StoreCategories.get_store_category_options_with_default(store.store_id)

        # Configure uploads
        socket = socket
        |> allow_upload(:product_images,
            accept: ~w(.jpg .jpeg .png .gif .webp),
            max_entries: 10,
            max_file_size: 10_000_000,
            auto_upload: true,
            progress: &handle_progress/3
          )
        |> allow_upload(:digital_file,
            accept: ~w(.pdf .zip .mp4),
            max_entries: 1,
            max_file_size: 300_000_000,
            auto_upload: true,
            progress: &handle_progress/3
          )

        socket = assign_form(socket, changeset, physical_categories, custom_categories)
          |> assign(:filtered_category_options, physical_categories)
          |> assign(:uploaded_images, [])
          |> assign(:uploaded_digital_file, nil)
          |> assign(:product_type, "physical")

        {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unable to create your store. Please try again.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      %Products.Product{}
      |> Products.change_product_creation(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset, socket.assigns.filtered_category_options, socket.assigns.custom_category_options)}
  end

  def handle_event("type_changed", %{"product" => %{"type" => product_type}}, socket) do
    IO.inspect(product_type, label: "Type changed to")

    filtered_category_options = if product_type && product_type != "" do
      Categories.get_categories_by_type(product_type)
    else
      # If no type selected, show all categories
      Categories.get_main_category_options()
    end

    # Update the form with the new type
    changeset = socket.assigns.form.source
    |> Ecto.Changeset.put_change(:type, product_type)
    |> Map.put(:action, :validate)

    form = to_form(changeset, as: "product")

    {:noreply,
     socket
     |> assign(form: form, filtered_category_options: filtered_category_options, product_type: product_type)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    # Check if the ref belongs to product_images or digital_file
    product_image_refs = Enum.map(socket.assigns.uploads.product_images.entries, & &1.ref)
    digital_file_refs = Enum.map(socket.assigns.uploads.digital_file.entries, & &1.ref)

    cond do
      ref in product_image_refs ->
        {:noreply, cancel_upload(socket, :product_images, ref)}
      ref in digital_file_refs ->
        {:noreply, cancel_upload(socket, :digital_file, ref)}
      true ->
        {:noreply, socket}
    end
  end

  def handle_event("remove_digital_file", _params, socket) do
    {:noreply, assign(socket, uploaded_digital_file: nil)}
  end

  def handle_event("upload_images", _params, socket) do
    # This event is no longer needed with auto_upload: true
    {:noreply, socket}
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

  def handle_event("save", %{"product" => product_params}, socket) do
    IO.puts("=== SAVE EVENT DEBUG ===")
    IO.puts("Product params: #{inspect(product_params)}")
    IO.puts("Uploaded digital file: #{inspect(socket.assigns.uploaded_digital_file)}")
    IO.puts("Uploaded images: #{inspect(socket.assigns.uploaded_images)}")

    # Build file data and merge with product params
    file_data = build_file_data(socket.assigns)
    IO.puts("File data: #{inspect(file_data)}")

    # Merge file data with product params and ensure all keys are strings
    complete_params = product_params
    |> Map.merge(file_data)
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
    IO.puts("Complete params: #{inspect(complete_params)}")

    # Get the user's default store for navigation
    user = socket.assigns.current_scope.user

    with {:ok, product} <- Products.create_user_product(user, complete_params) do
      success_message = build_success_message(socket.assigns)

      {:noreply,
       socket
       |> put_flash(:info, success_message)
       |> push_navigate(to: ~p"/#{user.username}/#{product.slug}")}
    else
      {:error, :no_store} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to access your store. Please try again.")
         |> push_navigate(to: ~p"/")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset, socket.assigns.filtered_category_options, socket.assigns.custom_category_options)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create product: #{reason}")}
    end
  end

  def handle_progress(:product_images, entry, socket) do
    if entry.done? do
      process_image_upload(entry, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_progress(:digital_file, entry, socket) do
    if entry.done? do
      process_digital_file_upload(entry, socket)
    else
      {:noreply, socket}
    end
  end

  defp process_image_upload(entry, socket) do
    with {:ok, temp_upload} <- create_temp_upload(entry, socket, :product_images),
         {:ok, image_url} <- store_image_to_r2(temp_upload) do
      current_images = socket.assigns.uploaded_images || []
      new_image = %{
        image_url: image_url,
        filename: entry.client_name,
        temp_id: generate_temp_id()
      }

      {:noreply,
       socket
       |> put_flash(:info, "Image '#{entry.client_name}' uploaded successfully!")
       |> assign(uploaded_images: current_images ++ [new_image])}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to upload image: #{reason}")}
    end
  end

  defp process_digital_file_upload(entry, socket) do
    IO.inspect(entry, label: "Processing digital file entry")

    # Upload directly to R2 without temp storage
    case upload_directly_to_r2(entry, socket) do
      {:ok, file_url} ->
        IO.inspect(file_url, label: "Successfully stored to R2")
        file_type = determine_file_type(entry.client_name)
        digital_file = %{
          file_url: file_url,
          filename: entry.client_name,
          file_type: file_type,
          temp_id: generate_temp_id()
        }

        {:noreply,
         socket
         |> put_flash(:info, "Digital file '#{entry.client_name}' uploaded successfully!")
         |> assign(uploaded_digital_file: digital_file)}
      {:error, reason} ->
        IO.inspect(reason, label: "R2 upload failed")
        {:noreply, put_flash(socket, :error, "Failed to upload digital file: #{inspect(reason)}")}
    end
  end

  defp create_temp_upload(entry, socket, upload_type) do
    IO.puts("=== CREATE TEMP UPLOAD DEBUG ===")
    IO.puts("Entry ref: #{entry.ref}")
    IO.puts("Upload type: #{upload_type}")
    IO.puts("Socket assigns keys: #{inspect(Map.keys(socket.assigns))}")

    uploaded_files = consume_uploaded_entries(socket, upload_type, fn meta, upload_entry ->
      IO.puts("Processing upload entry: ref=#{upload_entry.ref}, client_name=#{upload_entry.client_name}")
      if upload_entry.ref == entry.ref do
        IO.puts("✅ Found matching entry")
        {:ok, %{
          filename: upload_entry.client_name,
          path: meta.path,
          content_type: upload_entry.client_type
        }}
      else
        IO.puts("❌ Entry ref mismatch: expected #{entry.ref}, got #{upload_entry.ref}")
        {:error, :not_found}
      end
    end)

    IO.puts("Uploaded files result: #{inspect(uploaded_files)}")
    IO.puts("================================")

    case uploaded_files do
      [temp_upload] when is_map(temp_upload) ->
        IO.puts("✅ Successfully created temp upload: #{inspect(temp_upload)}")
        {:ok, temp_upload}
      [] ->
        IO.puts("❌ No uploaded files found")
        {:error, "No uploaded files found"}
      [error_result] ->
        IO.puts("❌ Upload error: #{inspect(error_result)}")
        {:error, "Upload error: #{inspect(error_result)}"}
      other ->
        IO.puts("❌ Unexpected result: #{inspect(other)}")
        {:error, "Unexpected upload result: #{inspect(other)}"}
    end
  end

  defp store_image_to_r2(temp_upload) do
    temp_product_id = generate_temp_id()
    Shomp.Uploads.store_product_image(temp_upload, temp_product_id)
  end

  defp upload_directly_to_r2(entry, socket) do
    IO.puts("=== DIRECT R2 UPLOAD DEBUG ===")
    IO.puts("Entry: #{inspect(entry)}")

    # Get the file data directly from the upload entry and read content before consuming
    case consume_uploaded_entries(socket, :digital_file, fn meta, upload_entry ->
      if upload_entry.ref == entry.ref do
        IO.puts("✅ Found matching entry for direct upload")

        # Read the file content before it gets consumed
        file_content = if File.exists?(meta.path) do
          File.read!(meta.path)
        else
          IO.puts("❌ File not found at path: #{meta.path}")
          {:error, "File not found"}
        end

        case file_content do
          {:error, reason} -> {:error, reason}
          content when is_binary(content) ->
            {:ok, %{
              filename: upload_entry.client_name,
              path: meta.path,
              content_type: upload_entry.client_type,
              content: content
            }}
        end
      else
        {:error, :not_found}
      end
    end) do
      [upload_data] when is_map(upload_data) ->
        IO.puts("✅ Got upload data: #{inspect(upload_data)}")
        temp_product_id = generate_temp_id()

        # Upload directly to R2
        Shomp.Uploads.store_digital_file(upload_data, temp_product_id)
      other ->
        IO.puts("❌ Failed to get upload data: #{inspect(other)}")
        {:error, "Failed to get upload data"}
    end
  end

  defp store_digital_file_to_r2(temp_upload) do
    temp_product_id = generate_temp_id()

    # Debug R2 config
    r2_config = Application.get_env(:shomp, :upload)[:r2]
    IO.inspect(r2_config, label: "R2 config loaded")

    Shomp.Uploads.store_digital_file(temp_upload, temp_product_id)
  end

  defp determine_file_type(filename) do
    filename
    |> Path.extname()
    |> String.downcase()
    |> case do
      ".pdf" -> "pdf"
      ".zip" -> "zip"
      ".mp4" -> "mp4"
      _ -> "unknown"
    end
  end

  defp generate_temp_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp update_product_with_files(product, socket) do
    file_data = build_file_data(socket.assigns)

    if map_size(file_data) > 0 do
      Products.update_product(product, file_data)
    else
      {:ok, product}
    end
  end

  defp build_file_data(assigns) do
    image_data = build_image_data(assigns.uploaded_images || [])
    digital_data = build_digital_data(assigns.uploaded_digital_file)

    IO.puts("=== BUILD FILE DATA DEBUG ===")
    IO.puts("Image data: #{inspect(image_data)}")
    IO.puts("Digital data: #{inspect(digital_data)}")

    final_data = Map.merge(image_data, digital_data)
    IO.puts("Final file data: #{inspect(final_data)}")
    final_data
  end

  defp build_image_data([]), do: %{}
  defp build_image_data([first_image | additional_images]) do
    additional_urls = Enum.map(additional_images, & &1.image_url)

    %{
      "image_original" => first_image.image_url,
      "additional_images" => additional_urls,
      "primary_image_index" => 0
    }
  end

  defp build_digital_data(nil), do: %{}
  defp build_digital_data(digital_file) do
    IO.puts("=== BUILD DIGITAL DATA DEBUG ===")
    IO.puts("Digital file: #{inspect(digital_file)}")
    %{
      "digital_file_url" => digital_file.file_url,
      "digital_file_type" => digital_file.file_type
    }
  end

  defp build_success_message(assigns) do
    image_count = length(assigns.uploaded_images || [])
    has_digital = assigns.uploaded_digital_file != nil

    cond do
      image_count > 0 and has_digital ->
        "Product created with #{image_count} images and digital file!"
      image_count > 0 ->
        "Product created with #{image_count} images!"
      has_digital ->
        "Product created with digital file!"
      true ->
        "Product created successfully!"
    end
  end


  defp assign_form(socket, %Ecto.Changeset{} = changeset, filtered_category_options, custom_category_options) do
    form = to_form(changeset, as: "product")
    assign(socket,
      form: form,
      filtered_category_options: filtered_category_options,
      custom_category_options: custom_category_options,
      uploaded_files: []
    )
  end



end
