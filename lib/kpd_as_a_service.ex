defmodule KpdAsAService do
  @moduledoc """
  KPD (Klasifikacija Proizvoda po Djelatnostima) as a Service.

  This module provides functions to list and search through hierarchical
  KPD product classification data with 6 levels of nesting.

  Each product class has Croatian and English names, a code, and validity dates.
  """

  import Ecto.Query
  alias KpdAsAService.Repo
  alias KpdAsAService.ProductClass

  @type search_opts :: [
          {:lang, :hr | :en | :both},
          {:level, 1..6 | nil},
          {:limit, pos_integer()},
          {:offset, non_neg_integer()},
          {:include_expired, boolean()}
        ]

  @doc """
  Lists all product classes, optionally filtered by level.

  ## Options
    - `:level` - Filter by specific level (1-6)
    - `:limit` - Maximum number of results (default: 100)
    - `:offset` - Offset for pagination (default: 0)
    - `:include_expired` - Include entries with past end_date (default: false)

  ## Examples

      iex> KpdAsAService.list()
      [%ProductClass{}, ...]

      iex> KpdAsAService.list(level: 1)
      [%ProductClass{level: 1}, ...]

  """
  @spec list(keyword()) :: [ProductClass.t()]
  def list(opts \\ []) do
    level = Keyword.get(opts, :level)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    include_expired = Keyword.get(opts, :include_expired, false)

    ProductClass
    |> maybe_filter_by_level(level)
    |> maybe_filter_expired(include_expired)
    |> order_by([pc], asc: pc.path)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Gets a single product class by its code.

  ## Examples

      iex> KpdAsAService.get_by_code("A01.11.11")
      %ProductClass{}

      iex> KpdAsAService.get_by_code("INVALID")
      nil

  """
  @spec get_by_code(String.t()) :: ProductClass.t() | nil
  def get_by_code(code) when is_binary(code) do
    Repo.get_by(ProductClass, code: code)
  end

  @doc """
  Gets a single product class by its code, raises if not found.
  """
  @spec get_by_code!(String.t()) :: ProductClass.t()
  def get_by_code!(code) when is_binary(code) do
    Repo.get_by!(ProductClass, code: code)
  end

  @doc """
  Gets a single product class by its ID.
  """
  @spec get(integer()) :: ProductClass.t() | nil
  def get(id) when is_integer(id) do
    Repo.get(ProductClass, id)
  end

  @doc """
  Gets all children of a product class (direct descendants only).

  ## Examples

      iex> KpdAsAService.get_children("A.01")
      [%ProductClass{path: "A.01.1"}, %ProductClass{path: "A.01.2"}, ...]

  """
  @spec get_children(String.t(), keyword()) :: [ProductClass.t()]
  def get_children(path, opts \\ []) when is_binary(path) do
    include_expired = Keyword.get(opts, :include_expired, false)
    current_level = path |> String.split(".") |> length()
    child_level = current_level + 1
    prefix = "#{path}.%"

    ProductClass
    |> where([pc], like(pc.path, ^prefix))
    |> where([pc], pc.level == ^child_level)
    |> maybe_filter_expired(include_expired)
    |> order_by([pc], asc: pc.path)
    |> Repo.all()
  end

  @doc """
  Gets all descendants of a product class (all levels below).

  ## Examples

      iex> KpdAsAService.get_descendants("A.01")
      [%ProductClass{path: "A.01.1"}, %ProductClass{path: "A.01.1.1"}, ...]

  """
  @spec get_descendants(String.t(), keyword()) :: [ProductClass.t()]
  def get_descendants(path, opts \\ []) when is_binary(path) do
    include_expired = Keyword.get(opts, :include_expired, false)
    prefix = "#{path}.%"

    ProductClass
    |> where([pc], like(pc.path, ^prefix))
    |> maybe_filter_expired(include_expired)
    |> order_by([pc], asc: pc.path)
    |> Repo.all()
  end

  @doc """
  Gets the parent of a product class.

  Returns nil for level 1 entries (roots).

  ## Examples

      iex> KpdAsAService.get_parent("A.01.1")
      %ProductClass{path: "A.01"}

      iex> KpdAsAService.get_parent("A")
      nil

  """
  @spec get_parent(String.t()) :: ProductClass.t() | nil
  def get_parent(path) when is_binary(path) do
    case ProductClass.parent_path(path) do
      nil -> nil
      parent_path -> Repo.get_by(ProductClass, path: parent_path)
    end
  end

  @doc """
  Gets all ancestors of a product class (from root to immediate parent).

  ## Examples

      iex> KpdAsAService.get_ancestors("A.01.1.1")
      [%ProductClass{path: "A"}, %ProductClass{path: "A.01"}, %ProductClass{path: "A.01.1"}]

  """
  @spec get_ancestors(String.t()) :: [ProductClass.t()]
  def get_ancestors(path) when is_binary(path) do
    ancestor_paths = ProductClass.build_ancestor_paths(path)

    if ancestor_paths == [] do
      []
    else
      ProductClass
      |> where([pc], pc.path in ^ancestor_paths)
      |> order_by([pc], asc: pc.level)
      |> Repo.all()
    end
  end

  @doc """
  Gets the full path from root to a specific product class.
  Returns the entry itself along with all its ancestors.

  ## Examples

      iex> KpdAsAService.get_full_path("A.01.1")
      [%ProductClass{path: "A"}, %ProductClass{path: "A.01"}, %ProductClass{path: "A.01.1"}]

  """
  @spec get_full_path(String.t()) :: [ProductClass.t()]
  def get_full_path(path) when is_binary(path) do
    all_paths = ProductClass.build_ancestor_paths(path) ++ [path]

    ProductClass
    |> where([pc], pc.path in ^all_paths)
    |> order_by([pc], asc: pc.level)
    |> Repo.all()
  end

  @doc """
  Searches for product classes using trigram similarity on names.
  Uses SQLite FTS5 with trigram tokenizer for fuzzy matching.

  ## Options
    - `:lang` - Language to search (:hr, :en, or :both, default: :both)
    - `:level` - Filter by specific level (1-6)
    - `:limit` - Maximum number of results (default: 20)
    - `:include_expired` - Include entries with past end_date (default: false)

  ## Examples

      iex> KpdAsAService.search("poljoprivreda")
      [%ProductClass{name_hr: "Poljoprivreda, šumarstvo i ribarstvo"}, ...]

      iex> KpdAsAService.search("agriculture", lang: :en)
      [%ProductClass{name_en: "Agriculture, forestry and fishing"}, ...]

  """
  @spec search(String.t(), search_opts()) :: [ProductClass.t()]
  def search(query, opts \\ []) when is_binary(query) do
    lang = Keyword.get(opts, :lang, :both)
    level = Keyword.get(opts, :level)
    limit = Keyword.get(opts, :limit, 20)
    include_expired = Keyword.get(opts, :include_expired, false)

    # Escape special FTS5 characters and prepare for trigram search
    escaped_query = escape_fts_query(query)

    # Build the FTS match expression based on language preference
    fts_match =
      case lang do
        :hr -> "name_hr:\"#{escaped_query}\""
        :en -> "name_en:\"#{escaped_query}\""
        :both -> "{name_hr name_en}:\"#{escaped_query}\""
      end

    # Query using FTS5 and join back to main table
    fts_query = """
    SELECT pc.*
    FROM product_classes pc
    INNER JOIN product_classes_fts fts ON pc.id = fts.rowid
    WHERE product_classes_fts MATCH ?
    ORDER BY fts.rank
    LIMIT ?
    """

    results =
      Repo.query!(fts_query, [fts_match, limit * 2])
      |> result_to_structs()

    # Apply additional filters in Elixir (since we're using raw SQL for FTS)
    results
    |> maybe_filter_by_level_list(level)
    |> maybe_filter_expired_list(include_expired)
    |> Enum.take(limit)
  end

  @doc """
  Searches product classes by exact or partial code match.

  ## Examples

      iex> KpdAsAService.search_by_code("A01")
      [%ProductClass{code: "A01"}, %ProductClass{code: "A01.11"}, ...]

  """
  @spec search_by_code(String.t(), keyword()) :: [ProductClass.t()]
  def search_by_code(code_prefix, opts \\ []) when is_binary(code_prefix) do
    limit = Keyword.get(opts, :limit, 20)
    include_expired = Keyword.get(opts, :include_expired, false)
    pattern = "#{code_prefix}%"

    ProductClass
    |> where([pc], like(pc.code, ^pattern))
    |> maybe_filter_expired(include_expired)
    |> order_by([pc], asc: pc.code)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns the total count of product classes.

  ## Options
    - `:level` - Count only entries at a specific level

  ## Examples

      iex> KpdAsAService.count()
      2847

      iex> KpdAsAService.count(level: 1)
      21

  """
  @spec count(keyword()) :: non_neg_integer()
  def count(opts \\ []) do
    level = Keyword.get(opts, :level)

    ProductClass
    |> maybe_filter_by_level(level)
    |> Repo.aggregate(:count)
  end

  @doc """
  Lists all root categories (level 1).
  """
  @spec list_roots(keyword()) :: [ProductClass.t()]
  def list_roots(opts \\ []) do
    list(Keyword.put(opts, :level, 1))
  end

  # Private helper functions

  defp maybe_filter_by_level(query, nil), do: query

  defp maybe_filter_by_level(query, level) when level in 1..6 do
    where(query, [pc], pc.level == ^level)
  end

  defp maybe_filter_expired(query, true), do: query

  defp maybe_filter_expired(query, false) do
    today = Date.utc_today()

    query
    |> where([pc], is_nil(pc.end_date) or pc.end_date >= ^today)
  end

  defp maybe_filter_by_level_list(list, nil), do: list

  defp maybe_filter_by_level_list(list, level) when level in 1..6 do
    Enum.filter(list, fn pc -> pc.level == level end)
  end

  defp maybe_filter_expired_list(list, true), do: list

  defp maybe_filter_expired_list(list, false) do
    today = Date.utc_today()
    Enum.filter(list, fn pc -> is_nil(pc.end_date) or Date.compare(pc.end_date, today) != :lt end)
  end

  defp escape_fts_query(query) do
    # Escape double quotes for FTS5 phrase search
    query
    |> String.replace("\"", "\"\"")
    |> String.trim()
  end

  defp result_to_structs(%{rows: rows, columns: columns}) do
    Enum.map(rows, fn row ->
      columns
      |> Enum.zip(row)
      |> Map.new()
      |> to_product_class()
    end)
  end

  defp to_product_class(map) do
    %ProductClass{
      id: map["id"],
      code: map["code"],
      path: map["path"],
      name_hr: map["name_hr"],
      name_en: map["name_en"],
      start_date: parse_date_from_db(map["start_date"]),
      end_date: parse_date_from_db(map["end_date"]),
      level: map["level"],
      inserted_at: parse_datetime_from_db(map["inserted_at"]),
      updated_at: parse_datetime_from_db(map["updated_at"])
    }
  end

  defp parse_date_from_db(nil), do: nil

  defp parse_date_from_db(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date_from_db(%Date{} = date), do: date

  defp parse_datetime_from_db(nil), do: nil

  defp parse_datetime_from_db(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> NaiveDateTime.from_iso8601!(datetime_string) |> DateTime.from_naive!("Etc/UTC")
    end
  end

  defp parse_datetime_from_db(%DateTime{} = datetime), do: datetime
end
