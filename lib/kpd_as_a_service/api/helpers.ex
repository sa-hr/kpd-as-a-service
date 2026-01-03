defmodule KpdAsAService.Api.Helpers do
  @moduledoc """
  Shared helper functions for API controllers.

  Provides utilities for parameter parsing and JSON response encoding.
  """

  import Plug.Conn

  # Response helpers

  @doc """
  Sends a JSON response with the given status code and data.
  """
  def json_response(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, JSON.encode!(data))
  end

  @doc """
  Encodes a list of product classes as a JSON response body.
  """
  def encode_product_classes(product_classes) do
    JSON.encode!(%{
      data: Enum.map(product_classes, &product_class_to_map/1),
      count: length(product_classes)
    })
  end

  @doc """
  Encodes a single product class as a JSON response body.
  """
  def encode_product_class(product_class) do
    JSON.encode!(%{data: product_class_to_map(product_class)})
  end

  defp product_class_to_map(pc) do
    %{
      code: pc.code,
      name_hr: pc.name_hr,
      name_en: pc.name_en,
      level: pc.level,
      start_date: date_to_string(pc.start_date),
      end_date: date_to_string(pc.end_date)
    }
  end

  defp date_to_string(nil), do: nil
  defp date_to_string(%Date{} = date), do: Date.to_iso8601(date)

  # Parameter parsing helpers

  @doc """
  Parses options for listing product classes.
  """
  def parse_list_opts(params) do
    []
    |> maybe_add_level(params)
    |> maybe_add_limit(params, 100)
    |> maybe_add_offset(params)
    |> maybe_add_include_expired(params)
  end

  @doc """
  Parses options for searching product classes.
  """
  def parse_search_opts(params) do
    []
    |> maybe_add_lang(params)
    |> maybe_add_level(params)
    |> maybe_add_limit(params, 20)
    |> maybe_add_include_expired(params)
  end

  @doc """
  Parses options for searching product classes by code.
  """
  def parse_code_search_opts(params) do
    []
    |> maybe_add_limit(params, 20)
    |> maybe_add_include_expired(params)
  end

  @doc """
  Parses options for hierarchy operations.
  """
  def parse_hierarchy_opts(params) do
    []
    |> maybe_add_include_expired(params)
  end

  defp maybe_add_level(opts, params) do
    case Map.get(params, "level") do
      nil ->
        opts

      level_str ->
        case Integer.parse(level_str) do
          {level, ""} when level in 1..6 -> Keyword.put(opts, :level, level)
          _ -> opts
        end
    end
  end

  defp maybe_add_limit(opts, params, default) do
    case Map.get(params, "limit") do
      nil ->
        Keyword.put(opts, :limit, default)

      limit_str ->
        case Integer.parse(limit_str) do
          {limit, ""} when limit > 0 -> Keyword.put(opts, :limit, min(limit, 1000))
          _ -> Keyword.put(opts, :limit, default)
        end
    end
  end

  defp maybe_add_offset(opts, params) do
    case Map.get(params, "offset") do
      nil ->
        opts

      offset_str ->
        case Integer.parse(offset_str) do
          {offset, ""} when offset >= 0 -> Keyword.put(opts, :offset, offset)
          _ -> opts
        end
    end
  end

  defp maybe_add_include_expired(opts, params) do
    case Map.get(params, "include_expired") do
      "true" -> Keyword.put(opts, :include_expired, true)
      "1" -> Keyword.put(opts, :include_expired, true)
      _ -> opts
    end
  end

  defp maybe_add_lang(opts, params) do
    case Map.get(params, "lang") do
      "hr" -> Keyword.put(opts, :lang, :hr)
      "en" -> Keyword.put(opts, :lang, :en)
      "all" -> Keyword.put(opts, :lang, :all)
      _ -> opts
    end
  end
end
