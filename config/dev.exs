import Config

# Dev-specific configuration
config :kpd_as_a_service, KpdAsAService.Repo,
  database: Path.expand("../priv/repo/kpd_dev.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
