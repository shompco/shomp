defmodule ShompWeb.RequestLive.Show do
  use ShompWeb, :live_view

  alias Shomp.FeatureRequests

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        <%= @request.title %>
        <:subtitle>Feature Request Details</:subtitle>
        <:actions>
          <.button navigate={~p"/requests"}>
            <.icon name="hero-arrow-left" />
            Back to Requests
          </.button>
          <%= if @current_scope && @current_scope.user && @current_scope.user.id == @request.user_id do %>
            <.button variant="primary" navigate={~p"/requests/#{@request}/edit?return_to=show"}>
              <.icon name="hero-pencil-square" /> Edit Request
            </.button>
          <% end %>
        </:actions>
      </.header>

      <div class="bg-white shadow rounded-lg p-6" id={"request-show-#{@request.id}"} phx-hook="VoteUpdates">
        <div class="flex items-start justify-between mb-6">
          <div class="flex-1">
            <div class="flex items-center space-x-3 mb-4">
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                <%= String.capitalize(@request.status) %>
              </span>
              <span class="text-sm text-gray-500">
                Priority: <%= @request.priority %>
              </span>
            </div>
            
            <p class="text-gray-700 text-lg leading-relaxed mb-4">
              <%= @request.description %>
            </p>
            
            <div class="flex items-center space-x-4 text-sm text-gray-500">
              <span>By @<%= @request.user.username %></span>
              <span><%= Calendar.strftime(@request.inserted_at, "%B %d, %Y") %></span>
            </div>
          </div>
          
          <div class="flex items-center space-x-6 ml-8">
            <div class="text-center">
              <div class="text-2xl font-bold text-gray-900" id={"vote-total-#{@request.id}"}>
                <%= FeatureRequests.get_request_vote_total(@request.id) %>
              </div>
              <div class="text-sm text-gray-500">votes</div>
            </div>
            
            <%= if @current_scope && @current_scope.user do %>
              <% current_vote = get_user_vote(@request, @current_scope.user.id) %>
              <div class="flex flex-col items-center space-y-2">
                <button 
                  phx-click="vote"
                  phx-value-request_id={@request.id}
                  phx-value-weight="1"
                  class={[
                    "transition-colors duration-200",
                    if(current_vote && current_vote.weight == 1, do: "text-green-600", else: "text-gray-400 hover:text-green-600")
                  ]}
                  title="Upvote"
                >
                  <svg class="w-8 h-8" fill={if(current_vote && current_vote.weight == 1, do: "currentColor", else: "none")} stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
                  </svg>
                </button>
                <button 
                  phx-click="vote"
                  phx-value-request_id={@request.id}
                  phx-value-weight="-1"
                  class={[
                    "transition-colors duration-200",
                    if(current_vote && current_vote.weight == -1, do: "text-red-600", else: "text-gray-400 hover:text-red-600")
                  ]}
                  title="Downvote"
                >
                  <svg class="w-8 h-8" fill={if(current_vote && current_vote.weight == -1, do: "currentColor", else: "none")} stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to vote updates for this specific feature request
      Phoenix.PubSub.subscribe(Shomp.PubSub, "feature_requests:votes")
    end

    {:ok,
     socket
     |> assign(:page_title, "Feature Request")
     |> assign(:request, FeatureRequests.get_request!(id))}
  end

  @impl true
  def handle_event("vote", %{"request_id" => request_id, "weight" => weight}, socket) do
    case Integer.parse(weight) do
      {weight_int, _} ->
        case FeatureRequests.vote_request(request_id, socket.assigns.current_scope.user.id, weight_int) do
          {:ok, _vote, user, action} ->
            # Broadcast the vote update to all connected users with more details
            Phoenix.PubSub.broadcast(
              Shomp.PubSub,
              "feature_requests:votes",
              {
                :vote_updated, 
                request_id, 
                FeatureRequests.get_request_vote_total(request_id),
                user.username,
                action,
                weight_int
              }
            )
            
            {:noreply, 
             socket
             |> assign(:request, FeatureRequests.get_request!(request_id))
             |> put_flash(:info, "Vote recorded!")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to record vote")}
        end
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid vote weight")}
    end
  end

  # Handle real-time vote updates from other users
  @impl true
  def handle_info({:vote_updated, request_id, new_total, username, action, weight}, socket) do
    # Update the vote total in real-time with enhanced information
    {:noreply, push_event(socket, "update_vote_total", %{
      request_id: request_id, 
      total: new_total, 
      username: username, 
      action: action, 
      weight: weight
    })}
  end

  defp get_user_vote(request, user_id) do
    Enum.find(request.votes, fn vote -> vote.user_id == user_id end)
  end
end
