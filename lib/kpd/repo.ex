defmodule KPD.Repo do
  use Ecto.Repo,
    otp_app: :kpd,
    adapter: Ecto.Adapters.SQLite3
end
