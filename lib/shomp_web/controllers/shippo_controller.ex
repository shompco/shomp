defmodule ShompWeb.ShippoController do
  use ShompWeb, :controller

  alias Shomp.UniversalOrders
  alias Shomp.NotificationServices

  @doc """
  Handles Shippo webhook events for tracking updates.
  """
  def webhook(conn, params) do
    # Log the webhook for debugging
    IO.puts("=== SHIPPO WEBHOOK RECEIVED ===")
    IO.puts("Headers: #{inspect(conn.req_headers)}")
    IO.puts("Params: #{inspect(params)}")
    IO.puts("Raw body: #{inspect(conn.assigns.raw_body)}")

    try do
      result = handle_shippo_webhook(params)
      IO.puts("Shippo webhook handling result: #{inspect(result)}")
      json(conn, %{received: true})
    rescue
      e ->
        IO.puts("ERROR: Exception during Shippo webhook handling: #{inspect(e)}")
        IO.puts("Stacktrace: #{inspect(__STACKTRACE__)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Webhook processing failed", details: inspect(e)})
    end
  end

  defp handle_shippo_webhook(params) do
    case params do
      %{"event" => "track_updated", "data" => %{"object_id" => tracking_id, "tracking_status" => %{"status" => status}}} ->
        IO.puts("=== TRACK UPDATED EVENT ===")
        IO.puts("Tracking ID: #{tracking_id}")
        IO.puts("Status: #{status}")

        # Find the universal order with this tracking number
        case UniversalOrders.get_universal_order_by_tracking_number(tracking_id) do
          nil ->
            IO.puts("No universal order found with tracking number: #{tracking_id}")
            {:ok, :order_not_found}

          universal_order ->
            IO.puts("Found universal order: #{universal_order.id}")

            # Map Shippo status to our internal status
            internal_status = map_shippo_status(status)
            IO.puts("Mapped status: #{internal_status}")

            # Update the universal order status
            case UniversalOrders.update_universal_order(universal_order, %{
              shipping_status: internal_status,
              tracking_status: status
            }) do
              {:ok, updated_order} ->
                IO.puts("Universal order updated successfully")

                # Send notifications based on status change
                send_shipping_notifications(updated_order, internal_status)

                # Broadcast the update
                Phoenix.PubSub.broadcast(Shomp.PubSub, "universal_orders", %{
                  event: "universal_order_updated",
                  payload: updated_order
                })

                {:ok, :status_updated}

              {:error, reason} ->
                IO.puts("ERROR: Failed to update universal order: #{inspect(reason)}")
                {:error, reason}
            end
        end

      %{"event" => "transaction_updated", "data" => %{"object_id" => transaction_id, "status" => status}} ->
        IO.puts("=== TRANSACTION UPDATED EVENT ===")
        IO.puts("Transaction ID: #{transaction_id}")
        IO.puts("Status: #{status}")

        # Handle transaction status updates (label generation, etc.)
        {:ok, :transaction_updated}

      _ ->
        IO.puts("Unknown Shippo webhook event: #{inspect(params)}")
        {:ok, :ignored}
    end
  end

  defp map_shippo_status(shippo_status) do
    case String.downcase(shippo_status) do
      "pre_transit" -> "label_created"
      "transit" -> "shipped"
      "delivered" -> "delivered"
      "returned" -> "returned"
      "failure" -> "failed"
      "unknown" -> "unknown"
      _ -> shippo_status
    end
  end

  defp send_shipping_notifications(universal_order, status) do
    IO.puts("=== SENDING SHIPPING NOTIFICATIONS ===")
    IO.puts("Status: #{status}")
    IO.puts("Universal Order ID: #{universal_order.id}")

    # Get the buyer user ID from the universal order
    buyer_user_id = universal_order.user_id

    case status do
      "shipped" ->
        IO.puts("Sending 'purchase shipped' notification to buyer")
        NotificationServices.notify_purchase_shipped(
          buyer_user_id,
          "Your order has shipped!",
          "Your order has been shipped and is on its way. Tracking: #{universal_order.tracking_number || "N/A"}"
        )

      "delivered" ->
        IO.puts("Sending 'purchase delivered' notification to buyer")
        NotificationServices.notify_purchase_delivered(
          buyer_user_id,
          "Your order has been delivered!",
          "Your order has been delivered. Thank you for your purchase!"
        )

      _ ->
        IO.puts("No notification needed for status: #{status}")
    end
  end
end
