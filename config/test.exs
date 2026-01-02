import Config

config :kpd_as_a_service, KpdAsAService.Repo,
  database: Path.expand("../kpd_as_a_service_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning
