defmodule GitBoy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      GitBoyWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: GitBoy.PubSub},
      # Start the Endpoint (http/https)
      GitBoyWeb.Endpoint,
      # Start the ProgrammingLanguages service
      GitBoy.ProgrammingLanguages
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GitBoy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GitBoyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
