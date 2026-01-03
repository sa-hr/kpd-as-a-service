import Config

config :kpd, KPD.Repo,
  database: Path.expand("../kpd_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning
