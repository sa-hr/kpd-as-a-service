defmodule KPD.Api.Controllers.ProductClassControllerTest do
  @moduledoc """
  Tests for ProductClassController - listing and search operations.
  """

  use KPD.DataCase, async: false

  import Plug.Test

  alias KPD.Api.Router

  @opts Router.init([])

  describe "GET /api/product_classes" do
    test "returns a list of product classes" do
      conn =
        conn(:get, "/api/product_classes")
        |> Router.call(@opts)

      assert %{
               "data" => [%{"code" => _, "name_hr" => _, "name_en" => _, "level" => _} | _],
               "count" => count
             } = JSON.decode!(conn.resp_body)

      assert conn.status == 200
      assert count > 0
    end

    test "does not expose internal fields (id, path)" do
      conn =
        conn(:get, "/api/product_classes?limit=1")
        |> Router.call(@opts)

      %{"data" => [first | _]} = JSON.decode!(conn.resp_body)

      refute Map.has_key?(first, "id")
      refute Map.has_key?(first, "path")
    end

    test "filters by level" do
      conn =
        conn(:get, "/api/product_classes?level=1")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"data" => items} = JSON.decode!(conn.resp_body)

      assert Enum.all?(items, &(&1["level"] == 1))
    end

    test "respects limit parameter" do
      conn =
        conn(:get, "/api/product_classes?limit=5")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"count" => count} = JSON.decode!(conn.resp_body)
      assert count <= 5
    end

    test "respects offset parameter" do
      %{"data" => page1} =
        conn(:get, "/api/product_classes?limit=10&offset=0")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      %{"data" => page2} =
        conn(:get, "/api/product_classes?limit=10&offset=10")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      page1_codes = MapSet.new(page1, & &1["code"])
      page2_codes = MapSet.new(page2, & &1["code"])

      assert MapSet.disjoint?(page1_codes, page2_codes)
    end
  end

  describe "GET /api/product_classes/roots" do
    test "returns only level 1 product classes" do
      conn =
        conn(:get, "/api/product_classes/roots")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"data" => items, "count" => count} = JSON.decode!(conn.resp_body)

      assert count > 0
      assert Enum.all?(items, &(&1["level"] == 1))
    end
  end

  describe "GET /api/product_classes/search" do
    test "searches product classes by name" do
      conn =
        conn(:get, "/api/product_classes/search?q=poljoprivreda")
        |> Router.call(@opts)

      assert conn.status == 200
      assert %{"data" => items} = JSON.decode!(conn.resp_body)
      assert is_list(items)
    end

    test "returns 400 when query is missing" do
      conn =
        conn(:get, "/api/product_classes/search")
        |> Router.call(@opts)

      assert conn.status == 400
      assert %{"error" => error} = JSON.decode!(conn.resp_body)
      assert error =~ "Missing required parameter"
    end

    test "returns 400 when query is empty" do
      conn =
        conn(:get, "/api/product_classes/search?q=")
        |> Router.call(@opts)

      assert conn.status == 400
      assert %{"error" => error} = JSON.decode!(conn.resp_body)
      assert error =~ "cannot be empty"
    end

    test "filters by language" do
      conn =
        conn(:get, "/api/product_classes/search?q=agriculture&lang=en")
        |> Router.call(@opts)

      assert conn.status == 200
      assert %{"data" => items} = JSON.decode!(conn.resp_body)
      assert is_list(items)
    end

    test "filters by level" do
      conn =
        conn(:get, "/api/product_classes/search?q=poljoprivreda&level=1")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"data" => items} = JSON.decode!(conn.resp_body)
      assert Enum.all?(items, &(&1["level"] == 1))
    end
  end

  describe "GET /api/product_classes/search_by_code" do
    test "searches product classes by code prefix" do
      conn =
        conn(:get, "/api/product_classes/search_by_code?code=A")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"data" => items} = JSON.decode!(conn.resp_body)
      assert Enum.all?(items, &String.starts_with?(&1["code"], "A"))
    end

    test "returns 400 when code is missing" do
      conn =
        conn(:get, "/api/product_classes/search_by_code")
        |> Router.call(@opts)

      assert conn.status == 400
      assert %{"error" => error} = JSON.decode!(conn.resp_body)
      assert error =~ "Missing required parameter"
    end
  end
end
