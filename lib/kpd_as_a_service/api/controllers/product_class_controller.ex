defmodule KPD.Api.Controllers.ProductClassController do
  @moduledoc """
  Controller for product class listing and search operations.

  Handles endpoints for:
  - Listing product classes with filtering
  - Listing root categories
  - Searching by name (fuzzy matching)
  - Searching by code prefix
  """

  import Plug.Conn
  alias KPD.Api.Helpers

  @doc """
  Lists product classes with optional filtering.

  Query parameters:
    - level: Filter by level (1-6)
    - limit: Maximum results (default: 100)
    - offset: Pagination offset (default: 0)
    - include_expired: Include expired entries (default: false)
  """
  def list(conn) do
    opts = Helpers.parse_list_opts(conn.query_params)
    product_classes = KPD.list(opts)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Helpers.encode_product_classes(product_classes))
  end

  @doc """
  Lists all root categories (level 1).
  """
  def roots(conn) do
    opts = Helpers.parse_list_opts(conn.query_params)
    product_classes = KPD.list_roots(opts)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Helpers.encode_product_classes(product_classes))
  end

  @doc """
  Search product classes by name using fuzzy matching.

  Query parameters:
    - q: Search query (required)
    - lang: Language to search (hr, en, all - default: all)
    - level: Filter by level (1-6)
    - limit: Maximum results (default: 20)
    - include_expired: Include expired entries (default: false)
  """
  def search(conn) do
    case Map.get(conn.query_params, "q") do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, JSON.encode!(%{error: "Missing required parameter: q"}))

      "" ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, JSON.encode!(%{error: "Search query cannot be empty"}))

      query ->
        opts = Helpers.parse_search_opts(conn.query_params)
        product_classes = KPD.search(query, opts)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Helpers.encode_product_classes(product_classes))
    end
  end

  @doc """
  Search product classes by code prefix.

  Query parameters:
    - code: Code prefix to search (required)
    - limit: Maximum results (default: 20)
    - include_expired: Include expired entries (default: false)
  """
  def search_by_code(conn) do
    case Map.get(conn.query_params, "code") do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, JSON.encode!(%{error: "Missing required parameter: code"}))

      "" ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, JSON.encode!(%{error: "Code prefix cannot be empty"}))

      code_prefix ->
        opts = Helpers.parse_code_search_opts(conn.query_params)
        product_classes = KPD.search_by_code(code_prefix, opts)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Helpers.encode_product_classes(product_classes))
    end
  end
end
