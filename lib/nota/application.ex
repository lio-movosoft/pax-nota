defmodule Nota.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NotaWeb.Telemetry,
      Nota.Repo,
      {DNSCluster, query: Application.get_env(:nota, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Nota.PubSub},
      # Start a worker by calling: Nota.Worker.start_link(arg)
      # {Nota.Worker, arg},
      # Start to serve requests, typically the last entry
      NotaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nota.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NotaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
