import Config

config :kpd_as_a_service, KpdAsAService.Repo,
  database: Path.expand("../priv/kpd_as_a_service.db", __DIR__),
  pool_size: 5

config :logger, level: :info
