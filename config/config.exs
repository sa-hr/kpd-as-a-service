import Config

config :kpd_as_a_service,
  ecto_repos: [KpdAsAService.Repo]

config :kpd_as_a_service, KpdAsAService.Repo,
  database: Path.expand("../kpd_as_a_service.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Import environment specific config
import_config "#{config_env()}.exs"
