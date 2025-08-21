defmodule ShompWeb.Plugs.RawBody do
  @moduledoc """
  Plug to capture raw body for webhook signature verification.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if webhook_path?(conn.request_path) do
      capture_raw_body(conn)
    else
      conn
    end
  end

  defp webhook_path?(path) do
    String.contains?(path, "/payments/webhook")
  end

  defp capture_raw_body(conn) do
    # Read the body and store it before Plug.Parsers consumes it
    case read_body(conn, read_length: 1_000_000) do
      {:ok, body, conn} ->
        assign(conn, :raw_body, body)
      
      {:more, body, conn} ->
        # Body is larger than read_length, read the rest
        case read_body(conn) do
          {:ok, rest, conn} ->
            full_body = body <> rest
            assign(conn, :raw_body, full_body)
          
          {:error, _reason} ->
            assign(conn, :raw_body, body)
        end
      
      {:error, _reason} ->
        assign(conn, :raw_body, "")
    end
  end
end
