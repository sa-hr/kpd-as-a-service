import Config

# In production releases (including Burrito), the database is located
# in the priv directory of the application. We use a compile-time
# path here, but it will be overridden at runtime for releases.
config :kpd, KPD.Repo,
  database: Path.expand("../priv/kpd.db", __DIR__),
  pool_size: 5

# HTTP server configuration defaults
# These can be overridden via environment variables in runtime.exs
config :kpd,
  server: true,
  port: 4000

config :logger, level: :info
