defmodule KPD.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        KPD.Repo
      ] ++ http_server_child()

    opts = [strategy: :one_for_one, name: KPD.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp http_server_child do
    if Application.get_env(:kpd, :start_http_server, false) do
      port = Application.get_env(:kpd, :http_port, 4000)
      [{Bandit, plug: KPD.Api.Router, port: port}]
    else
      []
    end
  end
end
