defmodule ShompWeb.AdminLive.KYCVerification do
  use ShompWeb, :live_view
  import Ecto.Query, warn: false
  alias Shomp.Stores.StoreKYCContext
  alias Shomp.Stores
  alias Shomp.AdminLogs
  alias Phoenix.PubSub

  @page_title "KYC Verification - Admin"
  @admin_email "v1nc3ntpull1ng@gmail.com"

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && 
       socket.assigns.current_scope.user.email == @admin_email do
      
      # Subscribe to KYC updates for real-time status changes
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Shomp.PubSub, "kyc_updates")
      end
      
      {:ok, 
       socket 
       |> assign(:page_title, @page_title)
       |> assign(:selected_kyc, nil)
       |> assign(:admin_notes, "")
       |> assign(:show_reject_modal, false)
       |> load_kyc_data()}
    else
      {:ok, 
       socket 
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_event("select_kyc", %{"kyc_id" => kyc_id}, socket) do
    kyc_id = String.to_integer(kyc_id)
    
    selected_kyc = Enum.find(socket.assigns.kyc_records, &(&1.id == kyc_id))
    
    {:noreply, 
     socket 
     |> assign(:selected_kyc, selected_kyc)
     |> assign(:admin_notes, selected_kyc.admin_notes || "")}
  end

  def handle_event("verify_kyc", %{"kyc_id" => kyc_id}, socket) do
    kyc_id = String.to_integer(kyc_id)
    
    # Find the current KYC record to check its status
    current_kyc = Enum.find(socket.assigns.kyc_records, &(&1.id == kyc_id))
    
    cond do
      current_kyc.status == "verified" ->
        {:noreply,
         socket
         |> put_flash(:info, "KYC is already approved")}
      
      true ->
        case StoreKYCContext.verify_kyc_by_id(kyc_id) do
          {:ok, _updated_kyc} ->
            # Log admin action
            AdminLogs.log_admin_action(
              socket.assigns.current_scope.user.id,
              "kyc_verified",
              "StoreKYC",
              kyc_id,
              "KYC verification approved",
              %{"action" => "verify", "kyc_id" => kyc_id}
            )
            
            # Update the selected KYC record in the assigns
            updated_kyc = %{current_kyc | status: "verified", verified_at: DateTime.utc_now() |> DateTime.truncate(:second)}
            updated_kyc_records = Enum.map(socket.assigns.kyc_records, fn kyc ->
              if kyc.id == kyc_id, do: updated_kyc, else: kyc
            end)
            
            # Update KYC stats
            updated_stats = update_kyc_stats(socket.assigns.kyc_stats, current_kyc.status, "verified")
            
            # Broadcast the KYC update to all connected clients
            Phoenix.PubSub.broadcast(Shomp.PubSub, "kyc_updates", %{
              event: "kyc_updated",
              payload: %{
                kyc_id: kyc_id,
                store_id: current_kyc.store.store_id,
                status: "verified"
              }
            })
            
            {:noreply,
             socket
             |> assign(:kyc_records, updated_kyc_records)
             |> assign(:selected_kyc, updated_kyc)
             |> assign(:kyc_stats, updated_stats)
             |> put_flash(:info, "KYC verification approved successfully")}
          
          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to verify KYC. Please try again.")}
        end
    end
  end

  def handle_event("reject_kyc", %{"kyc_id" => kyc_id, "reason" => reason}, socket) do
    kyc_id = String.to_integer(kyc_id)
    
    # Find the current KYC record to check its status
    current_kyc = Enum.find(socket.assigns.kyc_records, &(&1.id == kyc_id))
    
    cond do
      current_kyc.status == "rejected" ->
        {:noreply,
         socket
         |> put_flash(:info, "KYC is already rejected")}
      
      true ->
        case StoreKYCContext.reject_kyc_by_id(kyc_id, reason) do
          {:ok, _updated_kyc} ->
            # Log admin action
            AdminLogs.log_admin_action(
              socket.assigns.current_scope.user.id,
              "kyc_rejected",
              "StoreKYC",
              kyc_id,
              "KYC verification rejected: #{reason}",
              %{"action" => "reject", "kyc_id" => kyc_id, "reason" => reason}
            )
            
            # Update the selected KYC record in the assigns
            updated_kyc = %{current_kyc | status: "rejected", rejected_at: DateTime.utc_now() |> DateTime.truncate(:second), rejection_reason: reason}
            updated_kyc_records = Enum.map(socket.assigns.kyc_records, fn kyc ->
              if kyc.id == kyc_id, do: updated_kyc, else: kyc
            end)
            
            # Update KYC stats
            updated_stats = update_kyc_stats(socket.assigns.kyc_stats, current_kyc.status, "rejected")
            
            # Broadcast the KYC update to all connected clients
            Phoenix.PubSub.broadcast(Shomp.PubSub, "kyc_updates", %{
              event: "kyc_updated",
              payload: %{
                kyc_id: kyc_id,
                store_id: current_kyc.store.store_id,
                status: "rejected"
              }
            })
            
            {:noreply,
             socket
             |> assign(:kyc_records, updated_kyc_records)
             |> assign(:selected_kyc, updated_kyc)
             |> assign(:kyc_stats, updated_stats)
             |> assign(:show_reject_modal, false)
             |> put_flash(:info, "KYC verification rejected")}
          
          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to reject KYC. Please try again.")}
        end
    end
  end

  def handle_event("open_reject_modal", %{"kyc_id" => kyc_id}, socket) do
    {:noreply, assign(socket, show_reject_modal: true)}
  end

  def handle_event("close_reject_modal", _params, socket) do
    {:noreply, assign(socket, show_reject_modal: false)}
  end

  def handle_info(%{event: "kyc_updated", payload: %{kyc_id: kyc_id, store_id: store_id, status: status}}, socket) do
    # Update the KYC record in the list
    updated_kyc_records = Enum.map(socket.assigns.kyc_records, fn kyc ->
      if kyc.id == kyc_id do
        # Update the status and relevant timestamps
        updated_kyc = case status do
          "verified" -> 
            %{kyc | status: "verified", verified_at: DateTime.utc_now() |> DateTime.truncate(:second)}
          "rejected" -> 
            %{kyc | status: "rejected", rejected_at: DateTime.utc_now() |> DateTime.truncate(:second)}
          "submitted" -> 
            %{kyc | status: "submitted", submitted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
          _ -> 
            kyc
        end
        
        # Update selected_kyc if it's the same record
        if socket.assigns.selected_kyc && socket.assigns.selected_kyc.id == kyc_id do
          socket = assign(socket, selected_kyc: updated_kyc)
        end
        
        updated_kyc
      else
        kyc
      end
    end)
    
    # Update KYC stats
    updated_stats = update_kyc_stats(socket.assigns.kyc_stats, socket.assigns.kyc_records, updated_kyc_records)
    
    {:noreply, 
     socket
     |> assign(:kyc_records, updated_kyc_records)
     |> assign(:kyc_stats, updated_stats)}
  end

  def handle_info(%{event: "kyc_updated", payload: _payload}, socket) do
    # Ignore other KYC updates
    {:noreply, socket}
  end

  def handle_event("update_admin_notes", %{"kyc_id" => kyc_id, "notes" => notes}, socket) do
    kyc_id = String.to_integer(kyc_id)
    
    case StoreKYCContext.update_admin_notes_by_id(kyc_id, notes) do
      {:ok, _updated_kyc} ->
        # Log admin action
        AdminLogs.log_admin_action(
          socket.assigns.current_scope.user.id,
          "kyc_notes_updated",
          "StoreKYC",
          kyc_id,
          "Admin notes updated",
          %{"action" => "update_notes", "kyc_id" => kyc_id, "notes" => notes}
        )
        
        {:noreply,
         socket
         |> load_kyc_data()
         |> put_flash(:info, "Admin notes updated successfully")}
      
      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update admin notes. Please try again.")}
    end
  end

  def handle_event("sync_stripe_data", %{"kyc_id" => kyc_id}, socket) do
    kyc_id = String.to_integer(kyc_id)
    
    # Find the KYC record
    kyc = Enum.find(socket.assigns.kyc_records, &(&1.id == kyc_id))
    
    if kyc && kyc.stripe_account_id do
      # Sync with Stripe
      case Shomp.StripeConnect.sync_account_status(kyc.stripe_account_id) do
        {:ok, _updated_kyc} ->
          {:noreply,
           socket
           |> load_kyc_data()
           |> put_flash(:info, "Stripe data synced successfully")}
        
        {:error, _reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to sync Stripe data. Please try again.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "No Stripe account ID found for this KYC record.")}
    end
  end

  defp load_kyc_data(socket) do
    # Get all KYC records with store and user information
    kyc_records = get_kyc_records_with_details()
    
    socket
    |> assign(:kyc_records, kyc_records)
    |> assign(:kyc_stats, StoreKYCContext.get_kyc_stats())
  end

  defp get_kyc_records_with_details do
    StoreKYCContext.list_kyc_records_with_users()
  end

  defp update_kyc_stats(stats, old_status, new_status) do
    # Decrement the old status count
    stats = case old_status do
      "pending" -> %{stats | pending: max(0, stats.pending - 1)}
      "submitted" -> %{stats | submitted: max(0, stats.submitted - 1)}
      "verified" -> %{stats | verified: max(0, stats.verified - 1)}
      "rejected" -> %{stats | rejected: max(0, stats.rejected - 1)}
      _ -> stats
    end

    # Increment the new status count
    case new_status do
      "pending" -> %{stats | pending: stats.pending + 1}
      "submitted" -> %{stats | submitted: stats.submitted + 1}
      "verified" -> %{stats | verified: stats.verified + 1}
      "rejected" -> %{stats | rejected: stats.rejected + 1}
      _ -> stats
    end
  end

  defp update_kyc_stats(stats, old_records, new_records) do
    # Recalculate stats from the updated records
    %{
      pending: Enum.count(new_records, &(&1.status == "pending")),
      submitted: Enum.count(new_records, &(&1.status == "submitted")),
      verified: Enum.count(new_records, &(&1.status == "verified")),
      rejected: Enum.count(new_records, &(&1.status == "rejected"))
    }
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">KYC Verification</h1>
            <p class="text-base-content/70">Review and verify store KYC submissions</p>
          </div>
          <div class="flex items-center gap-4">
            <a href={~p"/admin"} class="btn btn-outline">
              ← Back to Admin Dashboard
            </a>
          </div>
        </div>
      </div>

      <!-- KYC Stats -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <.stat_card 
          title="Pending" 
          value={@kyc_stats.pending} 
          icon="⏳" 
          color="warning" />
        
        <.stat_card 
          title="Submitted" 
          value={@kyc_stats.submitted} 
          icon="📋" 
          color="info" />
        
        <.stat_card 
          title="Verified" 
          value={@kyc_stats.verified} 
          icon="✅" 
          color="success" />
        
        <.stat_card 
          title="Rejected" 
          value={@kyc_stats.rejected} 
          icon="❌" 
          color="error" />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- KYC List -->
        <div class="lg:col-span-1">
          <div class="bg-base-100 rounded-lg shadow p-6">
            <h2 class="text-xl font-bold mb-4">KYC Submissions</h2>
            <div class="space-y-3 max-h-96 overflow-y-auto">
              <%= for kyc <- @kyc_records do %>
                <div 
                  class={[
                    "border rounded-lg p-3 cursor-pointer transition-colors",
                    if(@selected_kyc && @selected_kyc.id == kyc.id, do: "border-primary bg-primary/5", else: "border-base-300 hover:border-primary/50")
                  ]}
                  phx-click="select_kyc"
                  phx-value-kyc_id={kyc.id}
                >
                  <div class="flex justify-between items-start">
                    <div class="flex-1">
                      <div class="flex items-center gap-2 mb-1">
                        <h3 class="font-semibold text-sm"><%= kyc.store.name %></h3>
                        <.status_badge status={kyc.status} />
                      </div>
                      <p class="text-xs text-base-content/70">@<%= kyc.user.username %></p>
                      <p class="text-xs text-base-content/50">
                        <%= Calendar.strftime(kyc.inserted_at, "%b %d, %Y") %>
                      </p>
                      <%= if kyc.id_document_path do %>
                        <div class="mt-1">
                          <span class="badge badge-xs badge-outline">📄 ID Document</span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= if Enum.empty?(@kyc_records) do %>
                <p class="text-base-content/50 text-center py-4">No KYC submissions yet</p>
              <% end %>
            </div>
          </div>
        </div>

        <!-- KYC Details -->
        <div class="lg:col-span-2">
          <%= if @selected_kyc do %>
            <div class="bg-base-100 rounded-lg shadow p-6">
              <div class="flex justify-between items-start mb-6">
                <div>
                  <h2 class="text-xl font-bold mb-2"><%= @selected_kyc.store.name %></h2>
                  <p class="text-base-content/70">@<%= @selected_kyc.user.username %></p>
                  <.status_badge status={@selected_kyc.status} />
                </div>
                <div class="flex gap-2">
                  <%= if @selected_kyc.stripe_account_id do %>
                    <button 
                      class="btn btn-sm btn-outline"
                      phx-click="sync_stripe_data"
                      phx-value-kyc_id={@selected_kyc.id}
                    >
                      🔄 Sync Stripe
                    </button>
                  <% end %>
                </div>
              </div>

              <!-- Store & User Info -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
                <div>
                  <h3 class="font-semibold mb-3">Store Information</h3>
                  <div class="space-y-2 text-sm">
                    <div><strong>Store ID:</strong> <%= @selected_kyc.store.store_id %></div>
                    <div><strong>Name:</strong> <%= @selected_kyc.store.name %></div>
                    <div><strong>Slug:</strong> <%= @selected_kyc.store.slug %></div>
                    <div><strong>Description:</strong> <%= @selected_kyc.store.description %></div>
                  </div>
                </div>
                
                <div>
                  <h3 class="font-semibold mb-3">User Information</h3>
                  <div class="space-y-2 text-sm">
                    <div><strong>Username:</strong> <%= @selected_kyc.user.username %></div>
                    <div><strong>Name:</strong> <%= @selected_kyc.user.name %></div>
                    <div><strong>Email:</strong> <%= @selected_kyc.user.email %></div>
                  </div>
                </div>
              </div>

              <!-- KYC Information -->
              <div class="mb-6">
                <h3 class="font-semibold mb-3">KYC Information</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <strong>Legal Name:</strong> 
                    <.kyc_field_value 
                      kyc_value={@selected_kyc.legal_name}
                      stripe_value={if @selected_kyc.stripe_individual_info && @selected_kyc.stripe_individual_info["first_name"] && @selected_kyc.stripe_individual_info["last_name"] do
                        "#{@selected_kyc.stripe_individual_info["first_name"]} #{@selected_kyc.stripe_individual_info["last_name"]}"
                      else
                        nil
                      end}
                    />
                  </div>
                  <div>
                    <strong>Business Type:</strong> 
                    <.kyc_field_value 
                      kyc_value={@selected_kyc.business_type}
                      stripe_value={nil}
                    />
                  </div>
                  <div>
                    <strong>Email:</strong> 
                    <.kyc_field_value 
                      kyc_value={@selected_kyc.email}
                      stripe_value={if @selected_kyc.stripe_individual_info, do: @selected_kyc.stripe_individual_info["email"]}
                    />
                  </div>
                  <div>
                    <strong>Phone:</strong> 
                    <.kyc_field_value 
                      kyc_value={@selected_kyc.phone}
                      stripe_value={if @selected_kyc.stripe_individual_info, do: @selected_kyc.stripe_individual_info["phone"]}
                    />
                  </div>
                </div>
              </div>

              <!-- Stripe Connect Information -->
              <%= if @selected_kyc.stripe_individual_info && not Enum.empty?(@selected_kyc.stripe_individual_info) do %>
                <div class="mb-6">
                  <h3 class="font-semibold mb-3">Stripe Connect Information</h3>
                  <div class="bg-white border border-gray-200 rounded-lg p-4">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-left">
                      <%= if @selected_kyc.stripe_individual_info["first_name"] do %>
                        <div class="text-black"><strong>First Name:</strong> <%= @selected_kyc.stripe_individual_info["first_name"] %></div>
                      <% end %>
                      <%= if @selected_kyc.stripe_individual_info["last_name"] do %>
                        <div class="text-black"><strong>Last Name:</strong> <%= @selected_kyc.stripe_individual_info["last_name"] %></div>
                      <% end %>
                      <%= if @selected_kyc.stripe_individual_info["email"] do %>
                        <div class="text-black"><strong>Email:</strong> <%= @selected_kyc.stripe_individual_info["email"] %></div>
                      <% end %>
                      <%= if @selected_kyc.stripe_individual_info["phone"] do %>
                        <div class="text-black"><strong>Phone:</strong> <%= @selected_kyc.stripe_individual_info["phone"] %></div>
                      <% end %>
                    </div>
                    <div class="mt-3 text-sm text-left">
                      <div class="text-black"><strong>Stripe Account ID:</strong> <%= @selected_kyc.stripe_account_id %></div>
                      <div class="text-black"><strong>Charges Enabled:</strong> <%= if @selected_kyc.charges_enabled, do: "✅", else: "❌" %></div>
                      <div class="text-black"><strong>Payouts Enabled:</strong> <%= if @selected_kyc.payouts_enabled, do: "✅", else: "❌" %></div>
                      <div class="text-black"><strong>Onboarding Completed:</strong> <%= if @selected_kyc.onboarding_completed, do: "✅", else: "❌" %></div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Name Comparison -->
              <%= if @selected_kyc.stripe_individual_info && @selected_kyc.legal_name do %>
                <div class="mb-6">
                  <h3 class="font-semibold mb-3">Name Comparison</h3>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <h4 class="font-medium text-blue-800 mb-2">ID Document Name</h4>
                        <p class="text-blue-700"><%= @selected_kyc.legal_name %></p>
                      </div>
                      <div>
                        <h4 class="font-medium text-blue-800 mb-2">Stripe Connect Name</h4>
                        <p class="text-blue-700">
                          <%= @selected_kyc.stripe_individual_info["first_name"] %> <%= @selected_kyc.stripe_individual_info["last_name"] %>
                        </p>
                      </div>
                    </div>
                    <div class="mt-3">
                      <.name_match_indicator 
                        id_name={@selected_kyc.legal_name}
                        stripe_first={@selected_kyc.stripe_individual_info["first_name"]}
                        stripe_last={@selected_kyc.stripe_individual_info["last_name"]}
                      />
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Document Preview -->
              <%= if @selected_kyc.id_document_path do %>
                <div class="mb-6">
                  <h3 class="font-semibold mb-3">ID Document</h3>
                  <div class="border border-base-300 rounded-lg p-4 bg-gray-50">
                    <%= if String.ends_with?(String.downcase(@selected_kyc.id_document_path), [".jpg", ".jpeg", ".png", ".gif", ".webp"]) do %>
                      <img 
                        src={~p"/kyc-images/#{Path.basename(@selected_kyc.id_document_path)}"} 
                        alt="ID Document" 
                        class="max-w-full h-auto max-h-96 mx-auto rounded-lg shadow-sm border border-gray-200"
                      />
                    <% else %>
                      <div class="flex items-center justify-center h-32 bg-gray-100 rounded-lg border border-gray-200">
                        <div class="text-center">
                          <svg class="mx-auto h-12 w-12 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          <p class="text-sm text-gray-600">PDF Document</p>
                          <p class="text-xs text-gray-500">File: <%= Path.basename(@selected_kyc.id_document_path) %></p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Admin Notes -->
              <div class="mb-6">
                <h3 class="font-semibold mb-3">Admin Notes</h3>
                <form phx-submit="update_admin_notes" phx-value-kyc_id={@selected_kyc.id}>
                  <textarea 
                    name="notes"
                    class="textarea textarea-bordered w-full h-24"
                    placeholder="Add admin notes..."
                  ><%= @selected_kyc.admin_notes %></textarea>
                  <div class="mt-2">
                    <button type="submit" class="btn btn-sm btn-outline">Update Notes</button>
                  </div>
                </form>
              </div>

              <!-- Action Buttons -->
              <div class="flex gap-4">
                <button 
                  class={[
                    "btn",
                    if(@selected_kyc.status == "verified", do: "btn-success btn-outline", else: "btn-success")
                  ]}
                  phx-click="verify_kyc"
                  phx-value-kyc_id={@selected_kyc.id}
                >
                  <%= if @selected_kyc.status == "verified" do %>
                    ✅ Already Approved
                  <% else %>
                    ✅ Approve Verification
                  <% end %>
                </button>
                
                <button 
                  class={[
                    "btn",
                    if(@selected_kyc.status == "rejected", do: "btn-error btn-outline", else: "btn-error")
                  ]}
                  phx-click="open_reject_modal"
                  phx-value-kyc_id={@selected_kyc.id}
                >
                  <%= if @selected_kyc.status == "rejected" do %>
                    ❌ Already Rejected
                  <% else %>
                    ❌ Reject Verification
                  <% end %>
                </button>
              </div>

              <!-- Rejection Reason Modal -->
              <%= if @show_reject_modal do %>
                <div class="modal modal-open">
                  <div class="modal-box">
                    <h3 class="font-bold text-lg mb-4">Reject KYC Verification</h3>
                    <form phx-submit="reject_kyc" phx-value-kyc_id={@selected_kyc.id}>
                      <div class="form-control">
                        <label class="label">
                          <span class="label-text">Rejection Reason</span>
                        </label>
                        <textarea 
                          name="reason"
                          class="textarea textarea-bordered"
                          placeholder="Please provide a reason for rejection..."
                          required
                        ></textarea>
                      </div>
                      <div class="modal-action">
                        <button type="button" class="btn btn-outline" phx-click="close_reject_modal">
                          Cancel
                        </button>
                        <button type="submit" class="btn btn-error">
                          Reject KYC
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="bg-base-100 rounded-lg shadow p-6">
              <div class="text-center py-12">
                <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <h3 class="text-lg font-medium text-gray-900 mb-2">Select a KYC Submission</h3>
                <p class="text-gray-500">Choose a KYC submission from the list to review and verify</p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="stat bg-base-100 shadow rounded-lg">
      <div class="stat-figure text-2xl"><%= @icon %></div>
      <div class="stat-title"><%= @title %></div>
      <div class={["stat-value", "text-#{@color}"]}><%= @value %></div>
    </div>
    """
  end

  defp status_badge(assigns) do
    color_class = case assigns.status do
      "pending" -> "badge-warning"
      "submitted" -> "badge-info"
      "verified" -> "badge-success"
      "rejected" -> "badge-error"
      _ -> "badge-outline"
    end

    ~H"""
    <span class={["badge badge-xs", color_class]}>
      <%= String.capitalize(assigns.status) %>
    </span>
    """
  end

  defp name_match_indicator(assigns) do
    # Simple name matching logic
    id_name = String.downcase(assigns.id_name || "")
    stripe_first = String.downcase(assigns.stripe_first || "")
    stripe_last = String.downcase(assigns.stripe_last || "")
    stripe_full = "#{stripe_first} #{stripe_last}" |> String.trim()
    
    # Check if names match (basic comparison)
    matches = String.contains?(id_name, stripe_first) && String.contains?(id_name, stripe_last)
    
    ~H"""
    <div class="flex items-center gap-2">
      <%= if @matches do %>
        <span class="text-green-600 font-medium">✅ Names Match</span>
      <% else %>
        <span class="text-red-600 font-medium">⚠️ Names Don't Match</span>
      <% end %>
    </div>
    """
  end

  defp kyc_field_value(assigns) do
    # Determine the value to display and its source
    {value, source} = cond do
      assigns.kyc_value && assigns.kyc_value != "" ->
        {assigns.kyc_value, :kyc}
      
      assigns.stripe_value && assigns.stripe_value != "" ->
        {assigns.stripe_value, :stripe}
      
      true ->
        {"Not provided", :none}
    end

    # Determine the styling based on source
    {text_class, badge} = case source do
      :kyc -> {"text-base-content", nil}
      :stripe -> {"text-blue-600", "from Stripe"}
      :none -> {"text-base-content/50", nil}
    end

    ~H"""
    <span class={text_class}>
      <%= value %>
      <%= if badge do %>
        <span class="badge badge-xs badge-info ml-1"><%= badge %></span>
      <% end %>
    </span>
    """
  end
end
