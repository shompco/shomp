defmodule ShompWeb.PurchaseActivitiesChannel do
  use ShompWeb, :channel

  def join("purchase_activities", _payload, socket) do
    # Subscribe to PubSub events
    Phoenix.PubSub.subscribe(Shomp.PubSub, "purchase_activities")
    {:ok, socket}
  end

  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{message: "pong"}}, socket}
  end

  def handle_info({:purchase_completed, activity_data}, socket) do
    # Forward the PubSub event to the channel clients
    push(socket, "purchase_completed", activity_data)
    {:noreply, socket}
  end
end
