defmodule KPD.Importer do
  @moduledoc """
  Module for loading KPD (Klasifikacija Proizvoda po Djelatnostima) product classes
  from CSV files into the database.

  The CSV is expected to have the following columns:
  - Službena šifra: Official code (redundant, already part of full code)
  - Datum početka: Start date (DD.MM.YYYY format)
  - Datum završetka: End date (DD.MM.YYYY format, may be empty)
  - Službeni naziv HR: Official Croatian name
  - Kratki naziv HR: Short Croatian name (unused)
  - Službeni naziv EN: Official English name
  - Kratki naziv EN: Short English name (unused)
  - Broj razine: Level number
  - Potpuna šifra: Full code (used to generate path)

  Data source:
  https://web.dzs.hr/app/klasus/
  """

  NimbleCSV.define(KPDParser, separator: ",", escape: "\"")

  alias KPD.Repo
  alias KPD.ProductClass

  require Logger

  @doc """
  Loads product classes from a CSV file into the database.

  ## Options
    - `:on_conflict` - Ecto on_conflict option (default: updates specified fields)
    - `:batch_size` - Number of rows per batch (default: 500)
    - `:max_concurrency` - Maximum parallel batch inserts (default: 4)

  Returns `{:ok, %{processed: count, errors: []}}` on success.

  Note: With batch inserts, we cannot distinguish between inserted and updated
  rows. The `processed` count represents successfully upserted rows.
  """
  @spec load_from_file(String.t(), keyword()) ::
          {:ok, %{processed: non_neg_integer(), errors: list()}} | {:error, term()}
  def load_from_file(file_path, opts \\ []) do
    if File.exists?(file_path) do
      do_load_from_file(file_path, opts)
    else
      {:error, {:file_not_found, file_path}}
    end
  end

  defp do_load_from_file(file_path, opts) do
    on_conflict =
      Keyword.get(
        opts,
        :on_conflict,
        {:replace, [:name_hr, :name_en, :start_date, :end_date, :updated_at]}
      )

    batch_size = Keyword.get(opts, :batch_size, 500)
    max_concurrency = Keyword.get(opts, :max_concurrency, 4)

    Logger.info("Starting KPD import from #{file_path}")

    file_path
    |> stream_csv_file()
    |> KPDParser.parse_stream(skip_headers: true)
    |> Stream.with_index(1)
    |> Stream.map(fn {row, line_num} ->
      case parse_row(row, line_num) do
        {:ok, attrs} -> {:ok, attrs, line_num}
        {:error, reason} -> {:error, line_num, reason}
      end
    end)
    |> Stream.chunk_every(batch_size)
    |> Task.async_stream(
      fn batch -> process_batch(batch, on_conflict) end,
      max_concurrency: max_concurrency,
      ordered: false
    )
    |> Enum.reduce(%{processed: 0, errors: []}, fn
      {:ok, batch_result}, acc ->
        %{
          processed: acc.processed + batch_result.processed,
          errors: batch_result.errors ++ acc.errors
        }

      {:exit, reason}, acc ->
        %{acc | errors: [{:task_exit, reason} | acc.errors]}
    end)
    |> tap(fn result ->
      Logger.info(
        "KPD import complete: #{result.processed} rows processed, #{length(result.errors)} errors"
      )
    end)
    |> then(&{:ok, &1})
  end

  defp process_batch(batch, on_conflict) do
    {valid, errors} =
      Enum.split_with(batch, fn
        {:ok, _, _} -> true
        {:error, _, _} -> false
      end)

    rows = Enum.map(valid, fn {:ok, attrs, _line_num} -> attrs end)

    {processed_count, _} =
      Repo.insert_all(ProductClass, rows,
        on_conflict: on_conflict,
        conflict_target: :code
      )

    %{
      processed: processed_count,
      errors: Enum.map(errors, fn {:error, line, reason} -> {line, reason} end)
    }
  end

  @doc """
  Transforms a full KPD code into a dot-separated path format.

  The transformation rules:
  1. First character (letter) becomes its own segment
  2. Next two digits stay together as the second segment
  3. Every subsequent digit becomes its own segment (original dots are ignored)

  ## Examples

      iex> Importer.transform_code_to_path("A")
      "A"

      iex> Importer.transform_code_to_path("A01")
      "A.01"

      iex> Importer.transform_code_to_path("A01.11.11")
      "A.01.1.1.1.1"

      iex> Importer.transform_code_to_path("C10.12.4")
      "C.10.1.2.4"

      iex> Importer.transform_code_to_path("C10.12.50")
      "C.10.1.2.5.0"

  """
  @spec transform_code_to_path(String.t()) :: String.t()
  def transform_code_to_path(code) when is_binary(code) do
    code = String.trim(code)

    case String.split_at(code, 1) do
      {letter, ""} ->
        # Level 1: just the letter
        letter

      {letter, rest} ->
        # Extract first two digits, then split remaining chars individually
        {first_two, remaining} = String.split_at(rest, 2)

        # Remove any dots from remaining and split each char
        remaining_chars =
          remaining
          |> String.replace(".", "")
          |> String.graphemes()

        segments = [letter, first_two | remaining_chars]

        Enum.join(segments, ".")
    end
  end

  @doc """
  Validates that the path has the expected number of levels.

  ## Examples

      iex> Importer.validate_level("A.01.1.1.1.1", 6)
      :ok

      iex> Importer.validate_level("A.01", 3)
      {:error, "Level mismatch: expected 3 levels, got 2"}

  """
  @spec validate_level(String.t(), integer()) :: :ok | {:error, String.t()}
  def validate_level(path, expected_level) when is_binary(path) and is_integer(expected_level) do
    actual_level = path |> String.split(".") |> length()

    if actual_level == expected_level do
      :ok
    else
      {:error, "Level mismatch: expected #{expected_level} levels, got #{actual_level}"}
    end
  end

  @doc """
  Rebuilds the FTS index from scratch.
  Useful after bulk imports that bypass triggers.
  """
  @spec rebuild_fts_index() :: :ok
  def rebuild_fts_index do
    Logger.info("Rebuilding FTS index...")

    # Delete all existing FTS entries
    Repo.query!("DELETE FROM product_classes_fts;")

    # Repopulate from main table
    Repo.query!("""
    INSERT INTO product_classes_fts(rowid, code, name_hr, name_en)
    SELECT id, code, name_hr, name_en FROM product_classes;
    """)

    Logger.info("FTS index rebuilt successfully")
    :ok
  end

  # Private functions

  defp stream_csv_file(file_path) do
    if String.ends_with?(file_path, ".gz") do
      # For gzipped files, use File.stream! with :compressed option
      File.stream!(file_path, [:compressed])
    else
      # For regular CSV files, use File.stream! normally
      File.stream!(file_path)
    end
  end

  defp parse_row(row, line_num) when length(row) >= 9 do
    [
      _code,
      start_date_str,
      end_date_str,
      name_hr,
      _short_name_hr,
      name_en,
      _short_name_en,
      level_str,
      full_code
    ] = Enum.take(row, 9)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with {:ok, start_date} <- parse_date(start_date_str),
         {:ok, end_date} <- parse_date(end_date_str),
         {:ok, level} <- parse_level(level_str),
         path <- transform_code_to_path(full_code),
         :ok <- validate_level(path, level) do
      {:ok,
       %{
         code: String.trim(full_code),
         path: path,
         name_hr: String.trim(name_hr),
         name_en: String.trim(name_en),
         start_date: start_date,
         end_date: end_date,
         level: level,
         inserted_at: now,
         updated_at: now
       }}
    end
  rescue
    e -> {:error, "Parse error on line #{line_num}: #{inspect(e)}"}
  end

  defp parse_row(_row, line_num) do
    {:error, "Invalid row format on line #{line_num}: expected at least 9 columns"}
  end

  defp parse_date(date_str) do
    date_str = String.trim(date_str)

    if date_str == "" do
      {:ok, nil}
    else
      case String.split(date_str, ".") do
        [day, month, year] ->
          with {d, ""} <- Integer.parse(day),
               {m, ""} <- Integer.parse(month),
               {y, ""} <- Integer.parse(year),
               {:ok, date} <- Date.new(y, m, d) do
            {:ok, date}
          else
            _ -> {:error, "Invalid date format: #{date_str}"}
          end

        _ ->
          {:error, "Invalid date format: #{date_str}"}
      end
    end
  end

  defp parse_level(level_str) do
    case level_str |> String.trim() |> Integer.parse() do
      {level, ""} -> {:ok, level}
      _ -> {:error, "Invalid level: #{level_str}"}
    end
  end
end
