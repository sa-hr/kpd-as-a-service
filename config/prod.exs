import Config

config :kpd, KPD.Repo,
  database: Path.expand("../priv/kpd.db", __DIR__),
  pool_size: 5

config :logger, level: :info
