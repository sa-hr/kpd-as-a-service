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
    if Application.get_env(:kpd, :server, false) do
      port = Application.get_env(:kpd, :port, 4000)
      ip = Application.get_env(:kpd, :ip, {0, 0, 0, 0})
      [{Bandit, plug: KPD.Api.Router, port: port, ip: ip}]
    else
      []
    end
  end
end
