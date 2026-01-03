defmodule Mix.Tasks.Kpd.Import do
  @moduledoc """
  Mix task to import KPD (Klasifikacija Proizvoda po Djelatnostima) data from a CSV file.

  ## Usage

      mix kpd.import path/to/kpd_data.csv

  ## Options

    * `--batch-size` - Number of rows to process per batch (default: 500)
    * `--rebuild-fts` - Rebuild the FTS index after import (default: false)

  ## Examples

      mix kpd.import priv/data/kpd.csv
      mix kpd.import priv/data/kpd.csv.gz --batch-size 1000
      mix kpd.import priv/data/kpd.csv --rebuild-fts

  """

  use Mix.Task

  @shortdoc "Imports KPD product classes from a CSV file"

  @switches [
    batch_size: :integer,
    rebuild_fts: :boolean
  ]

  @aliases [
    b: :batch_size,
    r: :rebuild_fts
  ]

  @impl Mix.Task
  def run(args) do
    {opts, args} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)

    case args do
      [file_path] ->
        import_file(file_path, opts)

      [] ->
        Mix.shell().error("Error: No file path provided")
        Mix.shell().info("\nUsage: mix kpd.import <path_to_csv>")
        exit({:shutdown, 1})

      _ ->
        Mix.shell().error("Error: Too many arguments")
        Mix.shell().info("\nUsage: mix kpd.import <path_to_csv>")
        exit({:shutdown, 1})
    end
  end

  defp import_file(file_path, opts) do
    if !File.exists?(file_path) do
      Mix.shell().error("Error: File not found: #{file_path}")
      exit({:shutdown, 1})
    end

    # Start the application to get Repo running
    Mix.Task.run("app.start")

    batch_size = Keyword.get(opts, :batch_size, 500)
    rebuild_fts = Keyword.get(opts, :rebuild_fts, false)

    Mix.shell().info("Importing KPD data from #{file_path}...")
    Mix.shell().info("Batch size: #{batch_size}")

    start_time = System.monotonic_time(:millisecond)

    case KPD.Importer.load_from_file(file_path, batch_size: batch_size) do
      {:ok, %{processed: processed, errors: errors}} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        Mix.shell().info("\n✓ Import completed in #{elapsed}ms")
        Mix.shell().info("  Processed: #{processed} rows")

        if length(errors) > 0 do
          Mix.shell().info("  Errors: #{length(errors)}")

          # Show first few errors
          errors
          |> Enum.take(5)
          |> Enum.each(fn {line, reason} ->
            Mix.shell().info("    Line #{line}: #{reason}")
          end)

          if length(errors) > 5 do
            Mix.shell().info("    ... and #{length(errors) - 5} more errors")
          end
        end

        if rebuild_fts do
          Mix.shell().info("\nRebuilding FTS index...")
          KPD.Importer.rebuild_fts_index()
          Mix.shell().info("✓ FTS index rebuilt")
        end

        :ok

      {:error, reason} ->
        Mix.shell().error("Import failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
