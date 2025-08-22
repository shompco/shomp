defmodule ShompWeb.ProfileLive.Edit do
  use ShompWeb, :live_view

  alias Shomp.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:page_title, "Edit Profile")}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="max-w-2xl mx-auto">
        <div class="bg-base-100 rounded-lg shadow-lg p-8">
          <h1 class="text-3xl font-bold mb-8">Edit Profile</h1>
          
          <form phx-submit="update_profile" class="space-y-6">
            <!-- Username -->
            <div class="form-control">
              <label class="label">
                <span class="label-text">Username</span>
                <span class="label-text-alt text-error">*</span>
              </label>
              <input
                type="text"
                name="username"
                value={@user.username || ""}
                class="input input-bordered w-full"
                placeholder="Enter your username"
                required
              />
              <label class="label">
                <span class="label-text-alt">This will be displayed publicly</span>
              </label>
            </div>

            <!-- Display Name -->
            <div class="form-control">
              <label class="label">
                <span class="label-text">Display Name</span>
              </label>
              <input
                type="text"
                name="name"
                value={@user.name || ""}
                class="input input-bordered w-full"
                placeholder="Enter your display name"
              />
              <label class="label">
                <span class="label-text-alt">Your full name (optional)</span>
              </label>
            </div>

            <!-- Bio -->
            <div class="form-control">
              <label class="label">
                <span class="label-text">Bio</span>
              </label>
              <textarea
                name="bio"
                class="textarea textarea-bordered w-full h-32"
                placeholder="Tell people about yourself..."
              ><%= @user.bio || "" %></textarea>
              <label class="label">
                <span class="label-text-alt">A short description about yourself</span>
              </label>
            </div>

            <!-- Location -->
            <div class="form-control">
              <label class="label">
                <span class="label-text">Location</span>
              </label>
              <input
                type="text"
                name="location"
                value={@user.location || ""}
                class="input input-bordered w-full"
                placeholder="City, State (optional)"
              />
              <label class="label">
                <span class="label-text-alt">City and state only for privacy</span>
              </label>
            </div>

            <!-- Website -->
            <div class="form-control">
              <label class="label">
                <span class="label-text">Website</span>
              </label>
              <input
                type="url"
                name="website"
                value={@user.website || ""}
                class="input input-bordered w-full"
                placeholder="https://yourwebsite.com"
              />
              <label class="label">
                <span class="label-text-alt">Your personal or business website</span>
              </label>
            </div>

            <!-- Submit Button -->
            <div class="form-control pt-4">
              <div class="flex gap-4">
                <button type="submit" class="btn btn-primary flex-1">
                  Update Profile
                </button>
                <.link href={~p"/users/#{@user.username}"} class="btn btn-outline flex-1">
                  👁️ View Profile
                </.link>
              </div>
            </div>
          </form>

          <!-- Current Profile Info -->
          <div class="divider">Current Profile</div>
          
          <div class="bg-base-200 rounded-lg p-6">
            <div class="flex items-center gap-4 mb-4">
              <div class="w-16 h-16 rounded-full bg-primary/20 flex items-center justify-center text-2xl font-bold text-primary">
                <%= String.first(@user.username || @user.name || "U") %>
              </div>
              <div>
                <h3 class="text-lg font-semibold">
                  <%= @user.username || @user.name || "Unnamed User" %>
                </h3>
                <p class="text-base-content/70">
                  Member since <%= Calendar.strftime(@user.inserted_at, "%B %Y") %>
                </p>
              </div>
            </div>
            
            <%= if @user.bio do %>
              <p class="text-base-content/80 mb-3">
                <%= @user.bio %>
              </p>
            <% end %>
            
            <div class="flex flex-wrap gap-2 text-sm">
              <%= if @user.location do %>
                <div class="badge badge-outline gap-2">
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd" />
                  </svg>
                  <%= @user.location %>
                </div>
              <% end %>
              
              <%= if @user.website do %>
                <div class="badge badge-outline gap-2">
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 2 2 0 002.828 0l3-3a2 2 0 012.828 0zM5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z" clip-rule="evenodd" />
                  </svg>
                  Website
                </div>
              <% end %>
            </div>
            
            <!-- View Profile Button -->
            <div class="mt-4">
              <.link href={~p"/users/#{@user.username}"} class="btn btn-outline btn-sm w-full">
                👁️ View Public Profile
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("update_profile", %{"username" => username, "name" => name, "bio" => bio, "location" => location, "website" => website}, socket) do
    user = socket.assigns.current_scope.user
    
    case Accounts.update_user(user, %{
      username: username,
      name: name,
      bio: bio,
      location: location,
      website: website
    }) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully!")
         |> assign(:user, updated_user)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update profile. Please check your input.")}
    end
  end
end
