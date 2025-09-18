defmodule ShompWeb.ProfileLive.Show do
  use ShompWeb, :live_view

  on_mount {ShompWeb.UserAuth, :mount_current_scope}

  alias Shomp.Accounts

  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_with_store_and_products(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Creator not found")
         |> redirect(to: ~p"/")}

      user ->
        {:ok,
         socket
         |> assign(:creator, user)
         |> assign(:products, user.products || [])
         |> assign(:page_title, "#{user.username || user.name}'s store")
         |> assign(:subscribed, false)}
    end
  end

  def handle_event("subscribe_to_creator", %{"email" => email}, socket) do
    creator = socket.assigns.creator

    # Create subscription with creator info in metadata
    subscription_attrs = %{
      email: email,
      source: "creator_page",
      metadata: %{
        creator_username: creator.username,
        creator_name: creator.name,
        creator_id: creator.id
      }
    }

    case Shomp.EmailSubscriptions.create_email_subscription(subscription_attrs) do
      {:ok, _subscription} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thanks for subscribing! You'll be notified when #{creator.username || creator.name} adds new products.")
         |> assign(:subscribed, true)}

      {:error, changeset} ->
        error_message = get_error_message(changeset)
        {:noreply, socket |> put_flash(:error, error_message)}
    end
  end

  defp get_error_message(changeset) do
    case changeset.errors do
      [email: {"has already been taken", _}] ->
        "This email is already subscribed to updates from this creator."
      [email: {"has invalid format", _}] ->
        "Please enter a valid email address."
      _ ->
        "There was an error subscribing. Please try again."
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="max-w-4xl mx-auto">
        <!-- Products Section -->
        <div class="bg-base-100 rounded-lg shadow-lg p-8">

          <%= if @products == [] do %>
            <div class="text-center py-12 text-base-content/60">
              <div class="mx-auto h-24 w-24 text-base-content/30 mb-4">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                </svg>
              </div>
              <p class="text-lg">No products yet</p>
              <p class="text-sm">This creator hasn't added any products yet.</p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              <%= for product <- @products do %>
                <div class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer overflow-hidden">
                  <!-- Product Image -->
                  <div class="aspect-square bg-base-300 flex items-center justify-center">
                    <%= if get_product_image(product) do %>
                      <img
                        src={get_product_image(product)}
                        alt={product.title}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <div class="text-base-content/40">
                        <svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      </div>
                    <% end %>
                  </div>

                  <div class="card-body p-4">
                    <h3 class="card-title text-lg line-clamp-2">
                      <.link href={get_product_url(product, @creator)} class="hover:text-primary">
                        <%= product.title %>
                      </.link>
                    </h3>
                    <p class="text-2xl font-bold text-primary mb-2">
                      $<%= product.price %>
                    </p>
                    <div class="flex items-center justify-between text-sm text-base-content/60 mb-4">
                      <span class="capitalize"><%= product.type %></span>
                      <span class={if product.quantity == 0 && product.type == "physical", do: "text-error", else: "text-success"}>
                        <%= if product.quantity == 0 && product.type == "physical", do: "Sold Out", else: "Available" %>
                      </span>
                    </div>
                    <div class="card-actions justify-end mt-4">
                      <.link href={get_product_url(product, @creator)} class="btn btn-primary btn-sm">
                        View Product
                      </.link>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

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
              <div class="flex items-center justify-between mb-4">
                <div class="flex items-center gap-3">
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

                <%= if @current_scope && @current_scope.user && @current_scope.user.id == @creator.id do %>
                  <.link
                    navigate={~p"/my/details"}
                    class="btn btn-outline btn-sm"
                  >
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                    Update Store and Profile Page
                  </.link>
                <% end %>
              </div>

              <p class="text-lg text-base-content/70 mb-4">
                Member since <%= Calendar.strftime(@creator.inserted_at, "%B %Y") %>
              </p>

              <!-- Bio -->
              <%= if @creator.bio do %>
                <p class="text-base-content/80 text-lg leading-relaxed mb-4">
                  <%= @creator.bio %>
                </p>
              <% end %>

              <div class="flex flex-wrap gap-4 text-sm text-base-content/60">
                <div class="flex items-center gap-2">
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd" />
                  </svg>
                  <%= length(@products) %> Product<%= if length(@products) != 1, do: "s", else: "" %>
                </div>
              </div>

              <!-- Email Signup Form -->
              <div class="mt-6 p-4 bg-base-200 rounded-lg">
                <%= if @subscribed do %>
                  <div class="text-center">
                    <div class="text-green-600 mb-2">
                      <svg class="w-8 h-8 mx-auto" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <h3 class="text-lg font-semibold text-green-600 mb-2">You're subscribed!</h3>
                    <p class="text-sm text-base-content/70">
                      You'll receive email updates when <%= @creator.username || @creator.name %> adds new products.
                    </p>
                  </div>
                <% else %>
                  <h3 class="text-lg font-semibold mb-3">Sign up for email updates on new products from this creator</h3>
                  <form phx-submit="subscribe_to_creator" class="flex gap-2">
                    <input
                      type="email"
                      name="email"
                      placeholder="Enter your email address"
                      class="input input-bordered flex-1"
                      required
                    />
                    <button type="submit" class="btn btn-primary">
                      Subscribe
                    </button>
                  </form>
                  <p class="text-xs text-base-content/60 mt-2">
                    Get notified when <%= @creator.username || @creator.name %> adds new products to their store.
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to get the best available image for a product
  defp get_product_image(product) do
    cond do
      # Try thumbnail first
      product.image_thumb && product.image_thumb != "" -> product.image_thumb
      # Fall back to original image
      product.image_original && product.image_original != "" -> product.image_original
      # Try medium image
      product.image_medium && product.image_medium != "" -> product.image_medium
      # Try large image
      product.image_large && product.image_large != "" -> product.image_large
      # Try additional images if available
      product.additional_images && length(product.additional_images) > 0 ->
        List.first(product.additional_images)
      # No image available
      true -> nil
    end
  end

  # Helper function to get product URL
  defp get_product_url(product, user) do
    if product.slug do
      "/#{user.username}/#{product.slug}"
    else
      "/#{user.username}/#{product.id}"
    end
  end
end
