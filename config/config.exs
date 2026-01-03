import Config

config :kpd,
  ecto_repos: [KPD.Repo]

config :kpd, KPD.Repo,
  database: Path.expand("../kpd.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Import environment specific config
import_config "#{config_env()}.exs"
