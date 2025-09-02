defmodule ShompWeb.StoreLive.KYC do
  use ShompWeb, :live_view

  alias Shomp.Stores.StoreKYCContext
  alias Shomp.Stores.StoreKYC

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    IO.puts("=== KYC MOUNT ===")
    user_id = socket.assigns.current_scope.user.id
    
    # Get the user's store
    case get_user_store(user_id) do
      nil ->
        IO.puts("No store found for user #{user_id}")
        {:ok,
         socket
         |> put_flash(:error, "You don't have a store yet")
         |> push_navigate(to: ~p"/new")}

      store ->
        IO.puts("Store found: #{inspect(store.id)}")
        # Get or create KYC record
        kyc_record = case StoreKYCContext.get_kyc_by_store_id(store.store_id) do
          nil ->
            IO.puts("No KYC record found, creating one...")
            {:ok, new_kyc} = StoreKYCContext.create_minimal_kyc(%{store_id: store.id})
            new_kyc
          existing_kyc ->
            IO.puts("Found existing KYC record: #{inspect(existing_kyc.id)}")
            existing_kyc
        end
        IO.puts("KYC Record: #{inspect(kyc_record)}")
        
        socket = socket
                 |> assign(:store, store)
                 |> assign(:kyc_record, kyc_record)
                 |> assign(:page_title, "Shomp KYC Verification")
                 |> allow_upload(:id_document, 
                   accept: ~w(.jpg .jpeg .png .pdf),
                   max_entries: 1,
                   max_file_size: 10_000_000) # 10MB
        
        IO.puts("Upload config: #{inspect(socket.assigns.uploads)}")
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
            <%= if @kyc_record && @kyc_record.id_document_path do %>
              <!-- Document Already Uploaded -->
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
                          <label for="id_document" class="relative cursor-pointer bg-white rounded-md font-medium text-primary hover:text-primary focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-primary">
                            <span>Upload a file</span>
                            <input 
                              id="id_document" 
                              name="id_document" 
                              type="file" 
                              class="sr-only" 
                              accept=".jpg,.jpeg,.png,.pdf"
                              phx-hook="FileUploadHook"
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
                      disabled={Enum.empty?(@uploads.id_document.entries)}
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
    IO.puts("=== KYC VALIDATE EVENT ===")
    IO.puts("Upload entries: #{inspect(socket.assigns.uploads.id_document.entries)}")
    IO.puts("Upload errors: #{inspect(socket.assigns.uploads.id_document.errors)}")
    {:noreply, socket}
  end

  def handle_event("submit_kyc", _params, socket) do
    IO.puts("=== KYC SUBMIT EVENT ===")
    IO.puts("Upload entries: #{inspect(socket.assigns.uploads.id_document.entries)}")
    IO.puts("Upload errors: #{inspect(socket.assigns.uploads.id_document.errors)}")
    
    store = socket.assigns.store
    kyc_record = socket.assigns.kyc_record
    
    # Consume the uploaded file
    case consume_uploaded_entries(socket, :id_document, fn %{path: path}, entry ->
      # Generate a unique filename
      filename = "#{store.store_id}_id_document_#{System.system_time(:millisecond)}.#{get_file_extension(entry.client_name)}"
      
      # Copy the file to the uploads directory
      dest = Path.join([Application.app_dir(:shomp, "priv/static/uploads/kyc"), filename])
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      
      # Return the relative path for storage
      "/uploads/kyc/#{filename}"
    end) do
      {[id_document_path], socket} ->
        # Update the KYC record with the uploaded document
        attrs = %{
          id_document_path: id_document_path,
          status: "submitted",
          submitted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        
        case StoreKYCContext.update_kyc(kyc_record.id, attrs) do
          {:ok, updated_kyc} ->
            {:noreply,
             socket
             |> assign(:kyc_record, updated_kyc)
             |> put_flash(:info, "ID document submitted successfully! Your verification is being reviewed.")}
          
          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to submit document. Please try again.")}
        end
      
      {[], socket} ->
        {:noreply,
         socket
         |> put_flash(:error, "Please upload an ID document before submitting.")}
    end
  end

  defp get_user_store(user_id) do
    alias Shomp.Stores
    stores = Stores.get_stores_by_user(user_id)
    IO.puts("Stores for user #{user_id}: #{inspect(stores)}")
    List.first(stores)
  end

  defp get_file_extension(filename) do
    filename
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end
end
