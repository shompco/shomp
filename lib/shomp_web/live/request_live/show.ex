defmodule ShompWeb.RequestLive.Show do
  use ShompWeb, :live_view

  alias Shomp.FeatureRequests

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Request {@request.id}
        <:subtitle>This is a request record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/requests"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/requests/#{@request}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit request
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@request.title}</:item>
        <:item title="Description">{@request.description}</:item>
        <:item title="Status">{@request.status}</:item>
        <:item title="Priority">{@request.priority}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Request")
     |> assign(:request, FeatureRequests.get_request!(id))}
  end

end
