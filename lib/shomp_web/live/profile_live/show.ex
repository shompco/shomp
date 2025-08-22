defmodule ShompWeb.ProfileLive.Show do
  use ShompWeb, :live_view

  alias Shomp.Accounts
  alias Shomp.Stores

  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Creator not found")
         |> redirect(to: ~p"/")}

      user ->
        stores = Stores.get_stores_by_user(user.id)
        
        {:ok,
         socket
         |> assign(:creator, user)
         |> assign(:stores, stores)
         |> assign(:page_title, "#{user.username || user.name}'s Profile")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="max-w-4xl mx-auto">
        <!-- Profile Header -->
        <div class="bg-base-100 rounded-lg shadow-lg p-8 mb-8">
          <div class="flex flex-col md:flex-row items-start gap-8">
            <!-- Avatar Section -->
            <div class="flex-shrink-0">
              <div class="w-32 h-32 rounded-full bg-primary/20 flex items-center justify-center text-4xl font-bold text-primary">
                <%= String.first(@creator.username || @creator.name || "U") %>
              </div>
            </div>
            
            <!-- Profile Info -->
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-4">
                <h1 class="text-3xl font-bold">
                  <%= @creator.username || @creator.name %>
                </h1>
                <%= if @creator.verified do %>
                  <div class="badge badge-success gap-2">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                    Verified Creator
                  </div>
                <% end %>
              </div>
              
              <p class="text-lg text-base-content/70 mb-4">
                Member since <%= Calendar.strftime(@creator.inserted_at, "%B %Y") %>
              </p>
              
              <div class="flex flex-wrap gap-4 text-sm text-base-content/60">
                <div class="flex items-center gap-2">
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd" />
                  </svg>
                  <%= length(@stores) %> Store<%= if length(@stores) != 1, do: "s", else: "" %>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Bio Section -->
        <%= if @creator.bio do %>
          <div class="bg-base-100 rounded-lg shadow-lg p-8 mb-8">
            <h2 class="text-2xl font-bold mb-4">About</h2>
            <p class="text-base-content/80 text-lg leading-relaxed">
              <%= @creator.bio %>
            </p>
          </div>
        <% end %>

        <!-- Links Section -->
        <%= if @creator.website || @creator.location do %>
          <div class="bg-base-100 rounded-lg shadow-lg p-8 mb-8">
            <h2 class="text-2xl font-bold mb-4">Links & Info</h2>
            <div class="space-y-4">
              <%= if @creator.website do %>
                <div class="flex items-center gap-3">
                  <svg class="w-5 h-5 text-primary flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 2 2 0 002.828 0l3-3a2 2 0 012.828 0zM5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z" clip-rule="evenodd" />
                  </svg>
                  <.link href={@creator.website} target="_blank" class="text-primary hover:underline break-all">
                    <%= @creator.website %>
                  </.link>
                </div>
              <% end %>
              
              <%= if @creator.location do %>
                <div class="flex items-center gap-3">
                  <svg class="w-5 h-5 text-primary flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd" />
                  </svg>
                  <span class="text-base-content/80">
                    <%= @creator.location %>
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Stores Section -->
        <div class="bg-base-100 rounded-lg shadow-lg p-8">
          <h2 class="text-2xl font-bold mb-6">Stores</h2>
          
          <%= if @stores == [] do %>
            <div class="text-center py-12 text-base-content/60">
              <svg class="w-16 h-16 mx-auto mb-4 text-base-content/30" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd" />
              </svg>
              <p class="text-lg">No stores yet</p>
              <p class="text-sm">This creator hasn't created any stores yet.</p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for store <- @stores do %>
                <div class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer">
                  <div class="card-body">
                    <h3 class="card-title text-lg">
                      <.link href={~p"/#{store.slug}"} class="hover:text-primary">
                        <%= store.name %>
                      </.link>
                    </h3>
                    <%= if store.description do %>
                      <p class="text-base-content/70 text-sm line-clamp-2">
                        <%= store.description %>
                      </p>
                    <% end %>
                    <div class="card-actions justify-end mt-4">
                      <.link href={~p"/#{store.slug}"} class="btn btn-primary btn-sm">
                        Visit Store
                      </.link>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
