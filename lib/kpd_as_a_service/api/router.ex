defmodule KPD.Api.Router do
  @moduledoc """
  HTTP API router for KPD product classification service.

  Provides REST endpoints for listing and searching product classes.
  Routes are handled by dedicated controllers for separation of concerns.
  """

  use Plug.Router

  alias KPD.Api.Controllers.{
    ProductClassController,
    ProductClassByCodeController,
    SystemController
  }

  alias KPD.Api.Helpers

  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Parsers, parsers: [:urlencoded, :json], json_decoder: JSON)
  plug(:dispatch)

  # Product class listing and search routes
  get "/api/product_classes" do
    ProductClassController.list(conn)
  end

  get "/api/product_classes/roots" do
    ProductClassController.roots(conn)
  end

  get "/api/product_classes/search" do
    ProductClassController.search(conn)
  end

  get "/api/product_classes/search_by_code" do
    ProductClassController.search_by_code(conn)
  end

  # Product class by code routes
  get "/api/product_classes/by_code/:code" do
    ProductClassByCodeController.show(conn, code)
  end

  get "/api/product_classes/by_code/:code/children" do
    ProductClassByCodeController.children(conn, code)
  end

  get "/api/product_classes/by_code/:code/descendants" do
    ProductClassByCodeController.descendants(conn, code)
  end

  get "/api/product_classes/by_code/:code/ancestors" do
    ProductClassByCodeController.ancestors(conn, code)
  end

  get "/api/product_classes/by_code/:code/full_path" do
    ProductClassByCodeController.full_path(conn, code)
  end

  get "/api/product_classes/by_code/:code/parent" do
    ProductClassByCodeController.parent(conn, code)
  end

  # System routes
  get "/api/stats" do
    SystemController.stats(conn)
  end

  get "/api/health" do
    SystemController.health(conn)
  end

  get "/api/openapi.yaml" do
    SystemController.openapi(conn)
  end

  # Catch-all for unmatched routes
  match _ do
    Helpers.json_response(conn, 404, %{error: "Not found"})
  end
end
