defmodule Shomp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShompWeb.Telemetry,
      Shomp.Repo,
      {DNSCluster, query: Application.get_env(:shomp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Shomp.PubSub},
      # Start a worker by calling: Shomp.Worker.start_link(arg)
      # {Shomp.Worker, arg},
      # Start to serve requests, typically the last entry
      ShompWeb.Endpoint
    ]

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
