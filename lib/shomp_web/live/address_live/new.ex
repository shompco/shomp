defmodule ShompWeb.AddressLive.New do
  use ShompWeb, :live_view

  alias Shomp.Addresses

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="mb-8">
          <.header>
            Add New Address
            <:subtitle>Add a new <%= @address_type %> address</:subtitle>
          </.header>
        </div>

        <div class="bg-base-100 shadow rounded-lg">
          <div class="px-6 py-4 border-b border-base-300">
            <h2 class="text-lg font-medium text-base-content">Address Information</h2>
          </div>
          
          <div class="p-6">
            <.form for={@form} phx-submit="save" class="space-y-6">
              <!-- Address Type (hidden) -->
              <input type="hidden" name="address[type]" value={@address_type} />
              
              <!-- Full Name -->
              <div>
                <.input 
                  field={@form[:name]} 
                  type="text" 
                  label="Full Name *"
                  placeholder="Enter full name"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <!-- Street Address -->
              <div>
                <.input 
                  field={@form[:street]} 
                  type="text" 
                  label="Street Address *"
                  placeholder="123 Main Street"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <!-- City, State, ZIP -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <.input 
                    field={@form[:city]} 
                    type="text" 
                    label="City *"
                    placeholder="City"
                    class="input input-bordered w-full"
                    required
                  />
                </div>

                <div>
                  <.input 
                    field={@form[:state]} 
                    type="text" 
                    label="State *"
                    placeholder="State"
                    class="input input-bordered w-full"
                    required
                  />
                </div>

                <div>
                  <.input 
                    field={@form[:zip_code]} 
                    type="text" 
                    label="ZIP Code *"
                    placeholder="12345"
                    class="input input-bordered w-full"
                    required
                  />
                </div>
              </div>

              <!-- Country -->
              <div>
                <.input 
                  field={@form[:country]} 
                  type="text" 
                  label="Country *"
                  value="US"
                  class="input input-bordered w-full"
                  readonly
                />
                <p class="text-sm text-base-content/70 mt-1">Currently only US addresses are supported</p>
              </div>

              <!-- Label (Optional) -->
              <div>
                <.input 
                  field={@form[:label]} 
                  type="text" 
                  label="Label (Optional)"
                  placeholder="e.g., Home, Work, etc."
                  class="input input-bordered w-full"
                />
              </div>

              <!-- Set as Default -->
              <div class="form-control">
                <.input 
                  field={@form[:is_default]} 
                  type="checkbox" 
                  label={"Set as default " <> @address_type <> " address"}
                  class="checkbox checkbox-primary"
                />
              </div>

              <!-- Use as billing address as well (only for shipping addresses) -->
              <%= if @address_type == "shipping" do %>
                <div class="form-control">
                  <.input 
                    field={@form[:use_as_billing]} 
                    type="checkbox" 
                    label="Use as billing address as well"
                    class="checkbox checkbox-secondary"
                  />
                  <p class="text-sm text-base-content/70 mt-1">This will create a copy of this address for billing purposes</p>
                </div>
              <% end %>

              <!-- Form Actions -->
              <div class="flex items-center justify-end space-x-4 pt-6 border-t border-base-300">
                <.link href={~p"/dashboard/addresses"} class="btn btn-outline">
                  Cancel
                </.link>
                <.button type="submit" class="btn btn-primary">
                  Save Address
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    address_type = params["type"] || "billing"
    
    # Validate address type
    unless address_type in ["billing", "shipping"] do
      raise Phoenix.Router.NoRouteError, "Address type not found"
    end
    
    changeset = Addresses.change_address_creation(%Addresses.Address{}, %{
      type: address_type,
      user_id: user.id,
      country: "US",
      use_as_billing: false
    })
    
    socket = 
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:address_type, address_type)
      |> assign(:page_title, "Add New Address")

    {:ok, socket}
  end

  @impl true
  def handle_event("save", %{"address" => address_params}, socket) do
    user = socket.assigns.current_scope.user
    
    attrs = Map.put(address_params, "user_id", user.id)
    
    case Addresses.create_address(attrs) do
      {:ok, _address} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Address created successfully")
         |> push_navigate(to: ~p"/dashboard/addresses")}
      
      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
