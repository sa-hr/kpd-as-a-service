defmodule KpdAsAService.Api.Controllers.SystemControllerTest do
  @moduledoc """
  Integration tests for the SystemController endpoints.

  Tests health checks, statistics, and API documentation.
  """

  use KpdAsAService.DataCase, async: false

  import Plug.Test
  import Plug.Conn

  alias KpdAsAService.Api.Router

  @opts Router.init([])

  describe "GET /api/health" do
    test "returns ok status" do
      conn =
        conn(:get, "/api/health")
        |> Router.call(@opts)

      assert conn.status == 200
      assert ["application/json; charset=utf-8"] = get_resp_header(conn, "content-type")
      assert %{"status" => "ok"} = JSON.decode!(conn.resp_body)
    end
  end

  describe "GET /api/stats" do
    test "returns statistics about product classes" do
      conn =
        conn(:get, "/api/stats")
        |> Router.call(@opts)

      assert conn.status == 200

      assert %{
               "total" => total,
               "by_level" => %{"level_1_sections" => sections}
             } = JSON.decode!(conn.resp_body)

      assert total > 0
      assert is_integer(sections)
    end
  end

  describe "GET /api/openapi.yaml" do
    test "returns OpenAPI specification" do
      conn =
        conn(:get, "/api/openapi.yaml")
        |> Router.call(@opts)

      assert conn.status == 200
      assert ["application/x-yaml; charset=utf-8"] = get_resp_header(conn, "content-type")
      assert conn.resp_body =~ "openapi: 3.0.3"
      assert conn.resp_body =~ "KPD Product Classification API"
    end
  end

  describe "404 handling" do
    test "returns 404 for unknown routes" do
      conn =
        conn(:get, "/api/unknown")
        |> Router.call(@opts)

      assert conn.status == 404
      assert %{"error" => "Not found"} = JSON.decode!(conn.resp_body)
    end
  end
end
