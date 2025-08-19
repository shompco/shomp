defmodule ShompWeb.RequestLive.Form do
  use ShompWeb, :live_view

  alias Shomp.FeatureRequests
  alias Shomp.FeatureRequests.Request

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage request records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="request-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:status]} type="select" label="Status" options={[
          {"Open", "open"},
          {"In Progress", "in_progress"}, 
          {"Completed", "completed"},
          {"Declined", "declined"}
        ]} />
        <.input field={@form[:priority]} type="number" label="Priority" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Request</.button>
          <.button navigate={return_path(@current_scope, @return_to, @request)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    # Require authentication for create/edit actions
    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:ok,
       socket
       |> assign(:return_to, return_to(params["return_to"]))
       |> apply_action(socket.assigns.live_action, params)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to create or edit feature requests.")
       |> redirect(to: ~p"/users/log-in")}
    end
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    request = FeatureRequests.get_request!(id)

    socket
    |> assign(:page_title, "Edit Request")
    |> assign(:request, request)
    |> assign(:form, to_form(FeatureRequests.change_request(request)))
  end

  defp apply_action(socket, :new, _params) do
    request = %Request{}

    socket
    |> assign(:page_title, "New Request")
    |> assign(:request, request)
    |> assign(:form, to_form(FeatureRequests.change_request(request)))
  end

  @impl true
  def handle_event("validate", %{"request" => request_params}, socket) do
    changeset = FeatureRequests.change_request(socket.assigns.request, request_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"request" => request_params}, socket) do
    save_request(socket, socket.assigns.live_action, request_params)
  end

  defp save_request(socket, :edit, request_params) do
    case FeatureRequests.update_request(socket.assigns.request, request_params) do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Request updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, request)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_request(socket, :new, request_params) do
    case FeatureRequests.create_request(request_params, socket.assigns.current_scope.user.id) do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Request created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, request)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _request), do: ~p"/requests"
  defp return_path(_scope, "show", request), do: ~p"/requests/#{request}"
end
