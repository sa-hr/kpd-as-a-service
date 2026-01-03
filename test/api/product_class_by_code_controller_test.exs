defmodule KPD.Api.Controllers.ProductClassByCodeControllerTest do
  @moduledoc """
  Integration tests for the ProductClassByCodeController.

  Tests endpoints for retrieving a single product class and its
  hierarchical relationships (children, descendants, ancestors, parent, full path).
  """

  use KPD.DataCase, async: false

  import Plug.Test

  alias KPD.Api.Router

  @opts Router.init([])

  # Helper to get a product class code at a specific level
  defp get_code_at_level(level) do
    %{"data" => [%{"code" => code} | _]} =
      conn(:get, "/api/product_classes?level=#{level}&limit=1")
      |> Router.call(@opts)
      |> Map.get(:resp_body)
      |> JSON.decode!()

    code
  end

  defp get_root_code do
    %{"data" => [%{"code" => code} | _]} =
      conn(:get, "/api/product_classes/roots?limit=1")
      |> Router.call(@opts)
      |> Map.get(:resp_body)
      |> JSON.decode!()

    code
  end

  describe "GET /api/product_classes/by_code/:code" do
    test "returns product class by code" do
      code = get_code_at_level(1)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}")
        |> Router.call(@opts)

      assert conn.status == 200
      assert %{"data" => %{"code" => ^code}} = JSON.decode!(conn.resp_body)
    end

    test "does not expose internal fields (id, path)" do
      code = get_code_at_level(1)

      %{"data" => data} =
        conn(:get, "/api/product_classes/by_code/#{code}")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      refute Map.has_key?(data, "id")
      refute Map.has_key?(data, "path")
    end

    test "returns 404 for non-existent code" do
      conn =
        conn(:get, "/api/product_classes/by_code/NONEXISTENT")
        |> Router.call(@opts)

      assert conn.status == 404
      assert %{"error" => error} = JSON.decode!(conn.resp_body)
      assert error =~ "not found"
    end
  end

  describe "GET /api/product_classes/by_code/:code/children" do
    test "returns children of a product class" do
      root_code = get_root_code()

      conn =
        conn(:get, "/api/product_classes/by_code/#{root_code}/children")
        |> Router.call(@opts)

      assert conn.status == 200
      %{"data" => children} = JSON.decode!(conn.resp_body)

      assert Enum.all?(children, &(&1["level"] == 2))
    end

    test "returns 404 for non-existent code" do
      conn =
        conn(:get, "/api/product_classes/by_code/NONEXISTENT/children")
        |> Router.call(@opts)

      assert conn.status == 404
    end
  end

  describe "GET /api/product_classes/by_code/:code/descendants" do
    test "returns descendants of a product class" do
      root_code = get_root_code()

      conn =
        conn(:get, "/api/product_classes/by_code/#{root_code}/descendants")
        |> Router.call(@opts)

      assert conn.status == 200
      %{"data" => descendants} = JSON.decode!(conn.resp_body)

      assert Enum.all?(descendants, &(&1["level"] > 1))
    end
  end

  describe "GET /api/product_classes/by_code/:code/ancestors" do
    test "returns ancestors of a product class" do
      code = get_code_at_level(3)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}/ancestors")
        |> Router.call(@opts)

      assert conn.status == 200
      # Level 3 item should have 2 ancestors (levels 1 and 2)
      assert %{"data" => [_, _], "count" => 2} = JSON.decode!(conn.resp_body)
    end
  end

  describe "GET /api/product_classes/by_code/:code/full_path" do
    test "returns full path from root to product class" do
      code = get_code_at_level(3)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}/full_path")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"data" => path, "count" => 3} = JSON.decode!(conn.resp_body)
      levels = Enum.map(path, & &1["level"])

      assert levels == [1, 2, 3]
    end
  end

  describe "GET /api/product_classes/by_code/:code/parent" do
    test "returns parent of a product class" do
      code = get_code_at_level(2)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}/parent")
        |> Router.call(@opts)

      assert conn.status == 200
      assert %{"data" => %{"level" => 1}} = JSON.decode!(conn.resp_body)
    end

    test "returns 404 for root level product class" do
      root_code = get_root_code()

      conn =
        conn(:get, "/api/product_classes/by_code/#{root_code}/parent")
        |> Router.call(@opts)

      assert conn.status == 404
      assert %{"error" => error} = JSON.decode!(conn.resp_body)
      assert error =~ "No parent"
    end
  end
end
