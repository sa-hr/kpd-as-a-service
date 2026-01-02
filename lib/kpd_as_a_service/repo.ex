defmodule KpdAsAService.Repo do
  use Ecto.Repo,
    otp_app: :kpd_as_a_service,
    adapter: Ecto.Adapters.SQLite3
end
