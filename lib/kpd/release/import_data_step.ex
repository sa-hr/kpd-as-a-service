defmodule KPD.Release.ImportDataStep do
  @moduledoc """
  Burrito build step that creates and populates the KPD database during release build.

  This step runs in the `patch` phase (post) and:
  1. Creates a fresh SQLite database in the release's priv directory
  2. Runs all Ecto migrations
  3. Imports KPD data from priv/data/kpd-2025.csv.gz
  4. Rebuilds the FTS index for search functionality

  The resulting database is bundled into the Burrito release, so the
  executable is self-contained with all KPD classification data.
  """

  # Note: This module implements the Burrito.Builder.Step behaviour, but we don't
  # declare it with @behaviour to avoid compile-time warnings since Burrito is
  # only available during release builds. The execute/1 callback is called by
  # Burrito during the patch phase of the build process.

  @doc """
  Executes the KPD data import step during the Burrito build process.

  Receives a `Burrito.Builder.Context` struct and returns it unchanged after
  populating the database with KPD classification data.
  """
  def execute(context) do
    log_info("Starting KPD data import step...")

    # Find the priv directory in the release
    app_version = context.mix_release.version
    priv_dir = Path.join([context.work_dir, "lib", "kpd-#{app_version}", "priv"])

    # Ensure priv directory exists
    File.mkdir_p!(priv_dir)

    db_path = Path.join(priv_dir, "kpd.db")
    csv_path = Path.join(priv_dir, "data/kpd-2025.csv.gz")

    log_info("Database path: #{db_path}")
    log_info("CSV path: #{csv_path}")

    # Remove any existing database to start fresh
    cleanup_existing_db(db_path)

    # Create and populate the database
    case create_and_populate_db(db_path, csv_path, priv_dir) do
      :ok ->
        log_success("KPD data import completed successfully!")

      {:error, reason} ->
        log_error("KPD data import failed: #{inspect(reason)}")
        raise "KPD data import failed: #{inspect(reason)}"
    end

    context
  end

  defp cleanup_existing_db(db_path) do
    # Remove SQLite database and its WAL/SHM files
    Enum.each([db_path, "#{db_path}-wal", "#{db_path}-shm"], fn path ->
      File.rm(path)
    end)
  end

  defp create_and_populate_db(db_path, csv_path, priv_dir) do
    # Temporarily override the Repo configuration for the build
    original_config = Application.get_env(:kpd, KPD.Repo)

    try do
      # Configure Repo to use the release database
      Application.put_env(:kpd, KPD.Repo,
        database: db_path,
        pool_size: 1
      )

      # Ensure required applications are started
      ensure_applications_started()

      # Start the Repo if not already started
      ensure_repo_started()

      # Run migrations
      run_migrations(priv_dir)

      # Import the KPD data
      import_kpd_data(csv_path)

      # Rebuild FTS index
      rebuild_fts_index()

      # Ensure all writes are flushed and close connections
      stop_repo()

      :ok
    rescue
      e ->
        {:error, Exception.message(e)}
    after
      # Restore original configuration
      if original_config do
        Application.put_env(:kpd, KPD.Repo, original_config)
      end
    end
  end

  defp ensure_applications_started do
    # These applications must be started for Ecto to work properly
    # Ecto.Repo.Registry is started as part of the :ecto application
    required_apps = [
      :crypto,
      :ssl,
      :telemetry,
      :db_connection,
      :ecto,
      :ecto_sql,
      :exqlite,
      :ecto_sqlite3
    ]

    Enum.each(required_apps, fn app ->
      case Application.ensure_all_started(app) do
        {:ok, _started} ->
          :ok

        {:error, {app, reason}} ->
          log_info("Warning: Could not start #{app}: #{inspect(reason)}")
      end
    end)
  end

  defp ensure_repo_started do
    case KPD.Repo.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> raise "Failed to start Repo: #{inspect(reason)}"
    end
  end

  defp stop_repo do
    # Execute a checkpoint to ensure WAL is flushed
    try do
      KPD.Repo.query!("PRAGMA wal_checkpoint(TRUNCATE);")
    rescue
      _ -> :ok
    end

    # Stop the repo
    try do
      GenServer.stop(KPD.Repo, :normal, 5000)
    rescue
      _ -> :ok
    end
  end

  defp run_migrations(priv_dir) do
    migrations_path = Path.join(priv_dir, "repo/migrations")

    Ecto.Migrator.run(KPD.Repo, migrations_path, :up, all: true, log: :info)
  end

  defp import_kpd_data(csv_path) do
    if !File.exists?(csv_path) do
      raise "CSV file not found: #{csv_path}"
    end

    case KPD.Importer.load_from_file(csv_path) do
      {:ok, %{processed: processed, errors: errors}} ->
        if length(errors) > 0 do
          log_info("Import warnings: #{length(errors)} rows had issues")
        end

        log_info("Imported #{processed} KPD product classes")
        :ok

      {:error, reason} ->
        raise "Import failed: #{inspect(reason)}"
    end
  end

  defp rebuild_fts_index do
    KPD.Importer.rebuild_fts_index()
  end

  # Logging helpers using Mix.shell() for build-time output
  defp log_info(message) do
    Mix.shell().info("--> #{message}")
  end

  defp log_success(message) do
    Mix.shell().info([:green, "--> ", message])
  end

  defp log_error(message) do
    Mix.shell().error("--> #{message}")
  end
end
