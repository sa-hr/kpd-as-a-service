import Config

# Dev-specific configuration
config :kpd, KPD.Repo,
  database: Path.expand("../priv/repo/kpd_dev.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# HTTP server configuration
config :kpd,
  start_http_server: true,
  http_port: 4000,
  enable_exsync: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
