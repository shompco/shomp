defmodule Shomp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ShompWeb.Telemetry,
      # Start the Ecto repository
      Shomp.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Shomp.PubSub},
      # Start Finch
      {Finch, name: Shomp.Finch},
      # Start the Endpoint (http/https)
      ShompWeb.Endpoint
      # Start a worker by calling: Shomp.Worker.start_link(arg)
      # {Shomp.Worker, arg}
    ]

    # Log Stripe configuration
    stripe_api_key = Application.get_env(:stripity_stripe, :api_key)
    stripe_publishable = Application.get_env(:shomp, :stripe_publishable_key)

    IO.puts("=== STRIPE CONFIGURATION ===")
    IO.puts("API Key: #{if stripe_api_key, do: String.slice(stripe_api_key, 0, 20) <> "...", else: "NOT SET"}")
    IO.puts("Publishable Key: #{if stripe_publishable, do: String.slice(stripe_publishable, 0, 20) <> "...", else: "NOT SET"}")
    IO.puts("=============================")

    # Log R2 configuration
    r2_bucket = System.get_env("R2_BUCKET")
    r2_endpoint = System.get_env("R2_ENDPOINT")
    r2_access_key_id = System.get_env("R2_ACCESS_KEY_ID")
    r2_secret_access_key = System.get_env("R2_SECRET_ACCESS_KEY")
    r2_region = System.get_env("R2_REGION") || "auto"

    IO.puts("=== R2 CONFIGURATION ===")
    IO.puts("Bucket: #{if r2_bucket, do: r2_bucket, else: "NOT SET"}")
    IO.puts("Endpoint: #{if r2_endpoint, do: r2_endpoint, else: "NOT SET"}")
    IO.puts("Access Key ID: #{if r2_access_key_id, do: String.slice(r2_access_key_id, 0, 20) <> "...", else: "NOT SET"}")
    IO.puts("Secret Access Key: #{if r2_secret_access_key, do: String.slice(r2_secret_access_key, 0, 20) <> "...", else: "NOT SET"}")
    IO.puts("Region: #{r2_region}")
    IO.puts("=========================")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Shomp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShompWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
