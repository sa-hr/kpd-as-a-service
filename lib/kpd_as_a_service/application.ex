defmodule KpdAsAService.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        KpdAsAService.Repo
      ] ++ http_server_child()

    opts = [strategy: :one_for_one, name: KpdAsAService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp http_server_child do
    if Application.get_env(:kpd_as_a_service, :start_http_server, false) do
      port = Application.get_env(:kpd_as_a_service, :http_port, 4000)
      [{Bandit, plug: KpdAsAService.Api.Router, port: port}]
    else
      []
    end
  end
end
