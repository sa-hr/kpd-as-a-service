import Config

# Runtime configuration for the KPD application.
# This file is loaded at runtime, after all other config files.
# It's ideal for configuring values from environment variables.

# HTTP Server Configuration
# -------------------------
# These settings control the HTTP server behavior in production.
#
# Environment variables:
#   - PORT: The port to listen on (default: 4000)
#   - IP: The IP address to bind to (default: "0.0.0.0")
#   - SERVER: Whether to start the HTTP server (default: "true")
#
# Examples:
#   PORT=8080 ./kpd_server
#   IP=127.0.0.1 PORT=3000 ./kpd_server
#   SERVER=false ./kpd_server  # Start without HTTP server

if config_env() == :prod do
  # Database configuration for releases
  # In a Burrito release, the database is bundled in the priv directory
  # and extracted alongside the application at runtime.
  db_path =
    case :code.priv_dir(:kpd) do
      {:error, :bad_name} ->
        # Fallback for non-release environments
        Path.expand("../priv/kpd.db", __DIR__)

      priv_dir ->
        # In a release, use the database from the priv directory
        Path.join(to_string(priv_dir), "kpd.db")
    end

  config :kpd, KPD.Repo,
    database: db_path,
    pool_size: 5

  # HTTP port configuration
  port =
    System.get_env("PORT", "4000")
    |> String.to_integer()

  # IP address to bind to
  ip =
    System.get_env("IP", "0.0.0.0")
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()

  # Whether to start the HTTP server
  server =
    System.get_env("SERVER", "true")
    |> String.downcase()
    |> Kernel.==("true")

  config :kpd,
    server: server,
    port: port,
    ip: ip
end
