defmodule ShompWeb.RequestLive.Index do
  use ShompWeb, :live_view

  alias Shomp.FeatureRequests

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Feature Requests
        <:actions>
          <.button variant="primary" navigate={~p"/requests/new"}>
            <.icon name="hero-plus" /> New Request
          </.button>
        </:actions>
      </.header>

      <div class="space-y-6">
        <%= for request <- @requests do %>
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center space-x-3 mb-2">
                  <h3 class="text-lg font-medium text-gray-900">
                    <.link navigate={~p"/requests/#{request}"} class="hover:text-blue-600">
                      <%= request.title %>
                    </.link>
                  </h3>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    <%= String.capitalize(request.status) %>
                  </span>
                </div>
                
                <p class="text-gray-600 mb-3 line-clamp-2">
                  <%= request.description %>
                </p>
                
                <div class="flex items-center justify-between text-sm text-gray-500">
                  <span>By <%= request.user.email %></span>
                  <span><%= Calendar.strftime(request.inserted_at, "%B %d, %Y") %></span>
                </div>
              </div>
              
              <div class="flex items-center space-x-4 ml-4">
                <div class="text-center">
                  <div class="text-lg font-semibold text-gray-900">
                    <%= FeatureRequests.get_request_vote_total(request.id) %>
                  </div>
                  <div class="text-xs text-gray-500">votes</div>
                </div>
                
                <%= if @current_scope && @current_scope.user do %>
                  <div class="flex items-center space-x-1">
                    <button 
                      phx-click="vote"
                      phx-value-request_id={request.id}
                      phx-value-weight="1"
                      class="text-gray-400 hover:text-blue-600"
                    >
                      👍
                    </button>
                    <button 
                      phx-click="vote"
                      phx-value-request_id={request.id}
                      phx-value-weight="2"
                      class="text-gray-400 hover:text-blue-600"
                    >
                      🔥
                    </button>
                    <button 
                      phx-click="vote"
                      phx-value-request_id={request.id}
                      phx-value-weight="3"
                      class="text-gray-400 hover:text-blue-600"
                    >
                      ⭐
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Feature Requests")
     |> assign(:requests, FeatureRequests.list_requests())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    request = FeatureRequests.get_request!(id)
    {:ok, _} = FeatureRequests.delete_request(request)

    {:noreply, 
     socket
     |> assign(:requests, FeatureRequests.list_requests())
     |> put_flash(:info, "Feature request deleted successfully!")}
  end

  def handle_event("vote", %{"request_id" => request_id, "weight" => weight}, socket) do
    case Integer.parse(weight) do
      {weight_int, _} ->
        case FeatureRequests.vote_request(request_id, socket.assigns.current_scope.user.id, weight_int) do
          {:ok, _} ->
            {:noreply, 
             socket
             |> assign(:requests, FeatureRequests.list_requests())
             |> put_flash(:info, "Vote recorded!")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to record vote")}
        end
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid vote weight")}
    end
  end
end
