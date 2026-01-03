defmodule KPD.Api.Controllers.ProductClassByCodeController do
  @moduledoc """
  Controller for product class operations by code.

  Handles endpoints for retrieving a single product class and its
  hierarchical relationships (children, descendants, ancestors, parent, full path).
  """

  import Plug.Conn
  alias KPD.Api.Helpers

  @doc """
  GET /api/product_classes/by_code/:code
  Get a single product class by its code.
  """
  def show(conn, code) do
    case KPD.get_by_code(code) do
      nil ->
        Helpers.json_response(conn, 404, %{error: "Product class not found"})

      product_class ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Helpers.encode_product_class(product_class))
    end
  end

  @doc """
  GET /api/product_classes/by_code/:code/children
  Get direct children of a product class.
  """
  def children(conn, code) do
    case KPD.get_by_code(code) do
      nil ->
        Helpers.json_response(conn, 404, %{error: "Product class not found"})

      product_class ->
        opts = Helpers.parse_hierarchy_opts(conn.query_params)
        children = KPD.get_children(product_class.path, opts)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Helpers.encode_product_classes(children))
    end
  end

  @doc """
  GET /api/product_classes/by_code/:code/descendants
  Get all descendants of a product class.
  """
  def descendants(conn, code) do
    case KPD.get_by_code(code) do
      nil ->
        Helpers.json_response(conn, 404, %{error: "Product class not found"})

      product_class ->
        opts = Helpers.parse_hierarchy_opts(conn.query_params)
        descendants = KPD.get_descendants(product_class.path, opts)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Helpers.encode_product_classes(descendants))
    end
  end

  @doc """
  GET /api/product_classes/by_code/:code/ancestors
  Get all ancestors of a product class.
  """
  def ancestors(conn, code) do
    case KPD.get_by_code(code) do
      nil ->
        Helpers.json_response(conn, 404, %{error: "Product class not found"})

      product_class ->
        ancestors = KPD.get_ancestors(product_class.path)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Helpers.encode_product_classes(ancestors))
    end
  end

  @doc """
  GET /api/product_classes/by_code/:code/full_path
  Get the full path from root to a product class.
  """
  def full_path(conn, code) do
    case KPD.get_by_code(code) do
      nil ->
        Helpers.json_response(conn, 404, %{error: "Product class not found"})

      product_class ->
        full_path = KPD.get_full_path(product_class.path)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Helpers.encode_product_classes(full_path))
    end
  end

  @doc """
  GET /api/product_classes/by_code/:code/parent
  Get the parent of a product class.
  """
  def parent(conn, code) do
    case KPD.get_by_code(code) do
      nil ->
        Helpers.json_response(conn, 404, %{error: "Product class not found"})

      product_class ->
        case KPD.get_parent(product_class.path) do
          nil ->
            Helpers.json_response(conn, 404, %{error: "No parent exists (root level)"})

          parent ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Helpers.encode_product_class(parent))
        end
    end
  end
end
