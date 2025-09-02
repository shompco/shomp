defmodule ShompWeb.StoreLive.KYC do
  use ShompWeb, :live_view

  alias Shomp.Stores.StoreKYCContext
  alias Phoenix.PubSub

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    
    # Get the user's store
    case get_user_store(user_id) do
      nil ->

        {:ok,
         socket
         |> put_flash(:error, "You don't have a store yet")
         |> push_navigate(to: ~p"/new")}

      store ->
        # Get or create KYC record
        kyc_record = case StoreKYCContext.get_kyc_by_store_id(store.store_id) do
          nil ->
            {:ok, new_kyc} = StoreKYCContext.create_minimal_kyc(%{store_id: store.id})
            new_kyc
          existing_kyc ->
            existing_kyc
        end
        
        socket = socket
                 |> assign(:store, store)
                 |> assign(:kyc_record, kyc_record)
                 |> assign(:page_title, "Shomp KYC Verification")
                 |> assign(:uploaded_files, [])
                 |> allow_upload(:id_document, 
                   accept: ~w(.jpg .jpeg .png .pdf),
                   max_entries: 1,
                   max_file_size: 10_000_000,
                   auto_upload: true,
                   progress: &handle_upload_progress/3) # 10MB
        

        {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Shomp KYC Verification</h1>
          <p class="text-lg text-gray-600 mt-2">Complete your identity verification to enable full store functionality</p>
        </div>

        <!-- Progress Indicator -->
        <div class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center">
              <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                </svg>
              </div>
              <span class="ml-2 text-sm font-medium text-gray-900">Stripe Connect</span>
            </div>
            <div class="flex-1 mx-4">
              <div class="h-1 bg-green-500 rounded"></div>
            </div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                <span class="text-sm font-medium text-white">2</span>
              </div>
              <span class="ml-2 text-sm font-medium text-gray-900">Shomp KYC</span>
            </div>
          </div>
        </div>

        <!-- Compliance Notice -->
        <div class="mb-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-blue-800">
                Compliance Notice
              </h3>
              <div class="mt-2 text-sm text-blue-700">
                <p>
                  In order to remain compliant, Shomp needs to verify your identity and it must match the identity used for Stripe Connect. 
                  Please ensure the information on your ID document matches the details you provided during Stripe Connect onboarding.
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Stripe Connect Information -->
        <%= if @kyc_record && @kyc_record.stripe_individual_info && not Enum.empty?(@kyc_record.stripe_individual_info) do %>
          <div class="mb-6 bg-green-50 border border-green-200 rounded-lg p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-green-800">
                  Stripe Connect Information
                </h3>
                <div class="mt-2 text-sm text-green-700">
                  <p class="mb-2">Please verify that your ID document matches the following information from your Stripe Connect account:</p>
                  <div class="space-y-1">
                    <%= if @kyc_record.stripe_individual_info["first_name"] do %>
                      <div><strong>Name:</strong> <%= @kyc_record.stripe_individual_info["first_name"] %> <%= @kyc_record.stripe_individual_info["last_name"] %></div>
                    <% end %>
                    <%= if @kyc_record.stripe_individual_info["email"] do %>
                      <div><strong>Email:</strong> <%= @kyc_record.stripe_individual_info["email"] %></div>
                    <% end %>
                    <%= if @kyc_record.stripe_individual_info["phone"] do %>
                      <div><strong>Phone:</strong> <%= @kyc_record.stripe_individual_info["phone"] %></div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- KYC Form -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Identity Verification</h2>
            <p class="text-sm text-gray-500 mt-1">
              Upload a clear photo of your government-issued ID to complete verification
            </p>
          </div>
          
          <div class="px-6 py-6">
            <%= if @kyc_record && @kyc_record.id_document_path && @kyc_record.status != "rejected" do %>
              <!-- Document Already Uploaded (not rejected) -->
              <div class="text-center py-8">
                <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100 mb-4">
                  <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h3 class="text-lg font-medium text-gray-900 mb-2">ID Document Uploaded</h3>
                <p class="text-sm text-gray-500 mb-4">
                  Your ID document has been submitted and is being reviewed.
                </p>
                <div class="text-sm text-gray-600">
                  Status: <span class="font-medium"><%= String.capitalize(@kyc_record.status) %></span>
                </div>
                <%= if @kyc_record.submitted_at do %>
                  <div class="text-sm text-gray-600 mt-1">
                    Submitted: <%= Calendar.strftime(@kyc_record.submitted_at, "%B %d, %Y at %I:%M %p") %>
                  </div>
                <% end %>
              </div>
            <% else %>
              <!-- Rejection Notice (if applicable) -->
              <%= if @kyc_record && @kyc_record.status == "rejected" do %>
                <div class="mb-6 bg-red-50 border border-red-200 rounded-lg p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-sm font-medium text-red-800">
                        Previous Submission Rejected
                      </h3>
                      <div class="mt-2 text-sm text-red-700">
                        <p class="mb-2">
                          Your previous KYC submission was rejected on 
                          <%= Calendar.strftime(@kyc_record.rejected_at, "%B %d, %Y at %I:%M %p") %>.
                        </p>
                        <%= if @kyc_record.rejection_reason do %>
                          <p class="mb-2"><strong>Reason:</strong> <%= @kyc_record.rejection_reason %></p>
                        <% end %>
                        <p>
                          Please upload a new, clear photo of your government-issued ID document below.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Upload Form -->
              <form phx-submit="submit_kyc" phx-change="validate_kyc" phx-upload-ref="id_document">
                <div class="space-y-6">
                  <!-- ID Document Upload -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Government-Issued ID Document
                    </label>
                    <p class="text-sm text-gray-500 mb-4">
                      Upload a clear photo of the front of your driver's license or US passport
                    </p>
                    
                    <div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md hover:border-gray-400 transition-colors">
                      <div class="space-y-1 text-center">
                        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                          <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                        </svg>
                        <div class="flex text-sm text-gray-600">
                          <label class="relative cursor-pointer bg-white rounded-md font-medium text-primary hover:text-primary focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-primary">
                            <span>Upload a file</span>
                            <.live_file_input 
                              upload={@uploads.id_document}
                              class="sr-only"
                            />
                          </label>
                          <p class="pl-1">or drag and drop</p>
                        </div>
                        <p class="text-xs text-gray-500">
                          PNG, JPG, PDF up to 10MB
                        </p>
                      </div>
                    </div>

                    <!-- Upload Progress -->
                    <%= for entry <- @uploads.id_document.entries do %>
                      <div class="mt-4">
                        <div class="flex items-center justify-between text-sm">
                          <span class="text-gray-600"><%= entry.client_name %></span>
                          <span class="text-gray-500"><%= entry.progress %>%</span>
                        </div>
                        <div class="mt-1 w-full bg-gray-200 rounded-full h-2">
                          <div class="bg-primary h-2 rounded-full" style={"width: #{entry.progress}%"}></div>
                        </div>
                        <%= if entry.progress == 100 do %>
                          <div class="mt-2 text-sm text-green-600">
                            ✅ Upload complete
                          </div>
                        <% end %>
                      </div>
                    <% end %>

                    <!-- Uploaded Image Preview -->
                    <%= if length(@uploaded_files) > 0 do %>
                      <div class="mt-6">
                        <h4 class="text-sm font-medium text-gray-900 mb-3">Uploaded Document Preview</h4>
                        <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
                          <%= for file_path <- @uploaded_files do %>
                            <div class="text-center">
                              <%= if String.ends_with?(String.downcase(file_path), [".jpg", ".jpeg", ".png", ".gif", ".webp"]) do %>
                                <img 
                                  src={~p"/kyc-images/#{file_path}"} 
                                  alt="Uploaded ID Document" 
                                  class="max-w-full h-auto max-h-96 mx-auto rounded-lg shadow-sm border border-gray-200 cursor-pointer hover:shadow-md transition-shadow"
                                  phx-click="view_kyc_image"
                                  phx-value-image-path={file_path}
                                />
                              <% else %>
                                <div class="flex items-center justify-center h-32 bg-gray-100 rounded-lg border border-gray-200">
                                  <div class="text-center">
                                    <svg class="mx-auto h-12 w-12 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                    </svg>
                                    <p class="text-sm text-gray-600">PDF Document</p>
                                    <p class="text-xs text-gray-500">File uploaded successfully</p>
                                  </div>
                                </div>
                              <% end %>
                              <div class="mt-2 flex items-center justify-center space-x-4">
                                <p class="text-sm text-gray-600">
                                  <%= Path.basename(file_path) %>
                                </p>
                                <button
                                  type="button"
                                  phx-click="remove_uploaded_file"
                                  phx-value-file-path={file_path}
                                  class="text-red-600 hover:text-red-800 text-sm font-medium"
                                >
                                  Remove
                                </button>
                              </div>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>

                    <!-- Upload Errors -->
                    <%= for {_ref, msg} <- @uploads.id_document.errors do %>
                      <div class="mt-2 text-sm text-red-600">
                        ❌ <%= Phoenix.Naming.humanize(msg) %>
                      </div>
                    <% end %>
                  </div>

                  <!-- Additional Information -->
                  <div class="bg-blue-50 border border-blue-200 rounded-md p-4">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <h3 class="text-sm font-medium text-blue-800">
                          Document Requirements
                        </h3>
                        <div class="mt-2 text-sm text-blue-700">
                          <ul class="list-disc list-inside space-y-1">
                            <li>Document must be government-issued (driver's license or US passport)</li>
                            <li>Photo must be clear and all text readable</li>
                            <li>Document must not be expired</li>
                            <li>File must be in JPG, PNG, or PDF format</li>
                            <li>Maximum file size: 10MB</li>
                          </ul>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Submit Button -->
                  <div class="flex justify-end">
                    <button 
                      type="submit" 
                      class="btn btn-primary"
                      disabled={Enum.empty?(@uploaded_files)}
                    >
                      Submit for Verification
                    </button>
                  </div>
                </div>
              </form>
            <% end %>
          </div>
        </div>

        <!-- Back to Balance -->
        <div class="mt-8 text-center">
          <a href="/dashboard/store/balance" class="text-sm text-gray-500 hover:text-gray-700">
            ← Back to Store Balance
          </a>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("validate_kyc", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("remove_uploaded_file", %{"file-path" => file_path}, socket) do
    # Remove the file from the uploaded_files list
    updated_files = Enum.reject(socket.assigns.uploaded_files, &(&1 == file_path))
    
    # Optionally delete the physical file
    try do
      full_path = Path.join([Application.app_dir(:shomp, "priv/secure_uploads/kyc"), file_path])
      if File.exists?(full_path) do
        File.rm!(full_path)
      end
    rescue
      _error ->
        # Ignore file deletion errors
    end
    
    {:noreply, assign(socket, uploaded_files: updated_files)}
  end

  def handle_event("view_kyc_image", %{"image-path" => image_path}, socket) do
    # Send event to JavaScript hook to open modal
    {:noreply, push_event(socket, "open_kyc_image", %{image_url: image_path, store_name: socket.assigns.store.name})}
  end

  def handle_event("submit_kyc", _params, socket) do
    _store = socket.assigns.store
    kyc_record = socket.assigns.kyc_record
    
    # Check if we have uploaded files ready to process
    uploaded_files = socket.assigns.uploaded_files || []
    
    if length(uploaded_files) > 0 do
      # Use the already uploaded file
      id_document_path = List.first(uploaded_files)
      
      # Update the KYC record with the uploaded document
      attrs = %{
        id_document_path: id_document_path,
        status: "submitted",
        submitted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
      
      case StoreKYCContext.update_kyc(kyc_record.id, attrs) do
        {:ok, updated_kyc} ->
          # Broadcast the KYC update to all connected clients
          Phoenix.PubSub.broadcast(Shomp.PubSub, "kyc_updates", %{
            event: "kyc_updated",
            payload: %{
              kyc_id: kyc_record.id,
              store_id: socket.assigns.store.store_id,
              status: "submitted"
            }
          })
          
          {:noreply,
           socket
           |> assign(:kyc_record, updated_kyc)
           |> put_flash(:info, "ID document submitted successfully! Your verification is being reviewed.")}
        
        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to submit document. Please try again.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please upload an ID document before submitting.")}
    end
  end

  def handle_upload_progress(:id_document, entry, socket) do
    if entry.done? do
      # Process the completed upload immediately
      process_completed_kyc_upload(entry, socket)
    else
      {:noreply, socket}
    end
  end

  defp process_completed_kyc_upload(entry, socket) do
    # Use consume_uploaded_entries to get the file path
    uploaded_files = consume_uploaded_entries(socket, :id_document, fn meta, upload_entry ->
      if upload_entry.ref == entry.ref do
        # Generate a unique filename using timestamp
        timestamp = System.system_time(:millisecond)
        extension = get_file_extension(upload_entry.client_name)
        filename = "#{timestamp}.#{extension}"
        
        # Copy the file to the secure uploads directory
        dest = Path.join([Application.app_dir(:shomp, "priv/secure_uploads/kyc"), filename])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(meta.path, dest)
        
        # Return just the filename for storage (not a web path)
        filename
      else
        nil
      end
    end)
    
    # Filter out failed uploads
    valid_files = Enum.filter(uploaded_files, & &1)
    
    if length(valid_files) > 0 do
      {:noreply, assign(socket, uploaded_files: valid_files)}
    else
      {:noreply, socket}
    end
  end

  defp get_user_store(user_id) do
    alias Shomp.Stores
    stores = Stores.get_stores_by_user(user_id)
    List.first(stores)
  end

  defp get_file_extension(filename) do
    filename
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end
end
