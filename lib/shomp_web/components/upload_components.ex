defmodule ShompWeb.UploadComponents do
  @moduledoc """
  Components for handling file and image uploads in forms.
  """
  
  use Phoenix.Component
  import Phoenix.HTML.Form
  
  @doc """
  Renders a file upload input for digital products.
  """
  def file_upload_input(assigns) do
    ~H"""
    <div class="space-y-2">
      <label class="block text-sm font-medium text-gray-700">
        Product File (Required for Digital Products)
      </label>
      
      <div class="flex items-center space-x-4">
        <input
          type="file"
          name="product_file"
          accept=".pdf,.zip,.rar,.doc,.docx,.xls,.xlsx,.txt,.md"
          class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
          required={@required}
        />
      </div>
      
      <p class="text-xs text-gray-500">
        Supported formats: PDF, ZIP, RAR, DOC, DOCX, XLS, XLSX, TXT, MD (Max: 10MB)
      </p>
    </div>
    """
  end
  
  @doc """
  Renders an image upload input for product images.
  """
  def image_upload_input(assigns) do
    ~H"""
    <div class="space-y-2">
      <label class="block text-sm font-medium text-gray-700">
        Product Images
      </label>
      
      <div class="flex items-center space-x-4">
        <.live_file_input 
          upload={@uploads.product_images}
          class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
        />
      </div>
      
      <p class="text-xs text-gray-500">
        Select image files. Files will be uploaded automatically when selected.
      </p>
      
      <!-- LiveView Upload Display -->
      <div class="mt-4">
        <%= for entry <- @uploads.product_images.entries do %>
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
              phx-click={Phoenix.LiveView.JS.push("cancel-upload", value: %{ref: entry.ref})}
              class="text-red-600 hover:text-red-800 text-sm font-medium"
            >
              Remove
            </button>
          </div>
        <% end %>
      </div>
      
      <!-- Error Messages -->
      <%= for {ref, error} <- @uploads.product_images.errors do %>
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
    """
  end

  @doc """
  Renders a multiple image upload input with preview and reordering capabilities.
  """
  def multiple_image_upload_input(assigns) do
    ~H"""
    <div class="space-y-2">
      <label class="block text-sm font-medium text-gray-700">
        Upload Multiple Images
      </label>
      
      <div class="flex items-center space-x-4">
        <.live_file_input 
          upload={@uploads.product_images}
          class="flex-1 block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
        />
        <button
          type="button"
          phx-click="upload_images"
          disabled={@uploads.product_images.entries == []}
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
        >
          Upload
        </button>
      </div>
      
      <p class="text-xs text-gray-500">
        Select multiple image files. You can reorder them after upload. The first image will be the primary product image.
      </p>
      
      <!-- LiveView Upload Display -->
      <div class="mt-4">
        <%= for entry <- @uploads.product_images.entries do %>
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
              phx-click={Phoenix.LiveView.JS.push("cancel-upload", value: %{ref: entry.ref})}
              class="text-red-600 hover:text-red-800 text-sm font-medium"
            >
              Remove
            </button>
          </div>
        <% end %>
      </div>
      
      <!-- Error Messages -->
      <%= for {ref, error} <- @uploads.product_images.errors do %>
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
    """
  end
  
  @doc """
  Renders a product image with fallback.
  """
  def product_image(assigns) do
    ~H"""
    <div class="relative group">
      <%= if @image_path do %>
        <img
          src={@image_path}
          alt={@alt || "Product image"}
          class="w-full h-48 object-cover rounded-lg shadow-sm group-hover:shadow-md transition-shadow duration-200"
        />
      <% else %>
        <div class="w-full h-48 bg-gray-200 rounded-lg flex items-center justify-center">
          <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </div>
      <% end %>
      
      <%= if @show_remove do %>
        <button
          type="button"
          class="absolute top-2 right-2 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity duration-200 hover:bg-red-600"
          phx-click="remove_image"
          phx-value-image-path={@image_path}
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders a product image gallery.
  """
  def product_gallery(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if @primary_image do %>
        <div class="relative">
          <img
            src={@primary_image}
            alt="Primary product image"
            class="w-full h-96 object-cover rounded-lg shadow-lg"
          />
        </div>
      <% end %>
      
      <%= if length(@additional_images) > 0 do %>
        <div class="grid grid-cols-4 gap-2">
          <%= for {image, index} <- Enum.with_index(@additional_images) do %>
            <div class="relative group cursor-pointer" phx-click="set_primary_image" phx-value-index={index}>
              <img
                src={image}
                alt="Product image #{index + 1}"
                class="w-full h-24 object-cover rounded-lg shadow-sm group-hover:shadow-md transition-shadow duration-200"
              />
              <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-20 transition-all duration-200 rounded-lg flex items-center justify-center">
                <span class="text-white opacity-0 group-hover:opacity-100 text-sm font-medium">
                  Set as Primary
                </span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
