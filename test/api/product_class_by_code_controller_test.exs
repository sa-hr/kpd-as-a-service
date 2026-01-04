defmodule KPD.Api.Controllers.ProductClassByCodeControllerTest do
  @moduledoc """
  Integration tests for the ProductClassByCodeController.

  Tests endpoints for retrieving a single product class and its
  hierarchical relationships (children, descendants, ancestors, parent, full path).

  All endpoints accept both full_code (e.g., "A01.11") and official_code (e.g., "01.11").
  """

  use KPD.DataCase, async: false

  import Plug.Test

  alias KPD.Api.Router

  @opts Router.init([])

  # Helper to get a product class with both code formats at a specific level
  defp get_codes_at_level(level) do
    %{"data" => [%{"full_code" => full_code, "official_code" => official_code} | _]} =
      conn(:get, "/api/product_classes?level=#{level}&limit=1")
      |> Router.call(@opts)
      |> Map.get(:resp_body)
      |> JSON.decode!()

    {full_code, official_code}
  end

  # Helper to get a product class code at a specific level (for backward compatibility)
  defp get_code_at_level(level) do
    {full_code, _official_code} = get_codes_at_level(level)
    full_code
  end

  defp get_root_codes do
    %{"data" => [%{"full_code" => full_code, "official_code" => official_code} | _]} =
      conn(:get, "/api/product_classes/roots?limit=1")
      |> Router.call(@opts)
      |> Map.get(:resp_body)
      |> JSON.decode!()

    {full_code, official_code}
  end

  defp get_root_code do
    {full_code, _official_code} = get_root_codes()
    full_code
  end

  describe "GET /api/product_classes/by_code/:code" do
    test "returns product class by full_code" do
      code = get_code_at_level(1)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}")
        |> Router.call(@opts)

      assert conn.status == 200
      assert %{"data" => %{"full_code" => ^code}} = JSON.decode!(conn.resp_body)
    end

    test "returns product class by official_code" do
      {full_code, official_code} = get_codes_at_level(2)

      conn =
        conn(:get, "/api/product_classes/by_code/#{official_code}")
        |> Router.call(@opts)

      assert conn.status == 200
      # Should return the same product class when looked up by official_code
      assert %{"data" => %{"full_code" => ^full_code, "official_code" => ^official_code}} =
               JSON.decode!(conn.resp_body)
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
    test "returns children of a product class using full_code" do
      root_code = get_root_code()

      conn =
        conn(:get, "/api/product_classes/by_code/#{root_code}/children")
        |> Router.call(@opts)

      assert conn.status == 200
      %{"data" => children} = JSON.decode!(conn.resp_body)

      assert Enum.all?(children, &(&1["level"] == 2))
    end

    test "returns children of a product class using official_code" do
      {_full_code, official_code} = get_codes_at_level(2)

      conn =
        conn(:get, "/api/product_classes/by_code/#{official_code}/children")
        |> Router.call(@opts)

      assert conn.status == 200
      %{"data" => children} = JSON.decode!(conn.resp_body)

      # Level 2 item's children should be at level 3
      assert Enum.all?(children, &(&1["level"] == 3))
    end

    test "returns 404 for non-existent code" do
      conn =
        conn(:get, "/api/product_classes/by_code/NONEXISTENT/children")
        |> Router.call(@opts)

      assert conn.status == 404
    end
  end

  describe "GET /api/product_classes/by_code/:code/descendants" do
    test "returns descendants of a product class using full_code" do
      root_code = get_root_code()

      conn =
        conn(:get, "/api/product_classes/by_code/#{root_code}/descendants")
        |> Router.call(@opts)

      assert conn.status == 200
      %{"data" => descendants} = JSON.decode!(conn.resp_body)

      assert Enum.all?(descendants, &(&1["level"] > 1))
    end

    test "returns descendants of a product class using official_code" do
      {_full_code, official_code} = get_codes_at_level(2)

      conn =
        conn(:get, "/api/product_classes/by_code/#{official_code}/descendants")
        |> Router.call(@opts)

      assert conn.status == 200
      %{"data" => descendants} = JSON.decode!(conn.resp_body)

      # Level 2 item's descendants should be at level 3 or higher
      assert Enum.all?(descendants, &(&1["level"] > 2))
    end
  end

  describe "GET /api/product_classes/by_code/:code/ancestors" do
    test "returns ancestors of a product class using full_code" do
      code = get_code_at_level(3)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}/ancestors")
        |> Router.call(@opts)

      assert conn.status == 200
      # Level 3 item should have 2 ancestors (levels 1 and 2)
      assert %{"data" => [_, _], "count" => 2} = JSON.decode!(conn.resp_body)
    end

    test "returns ancestors of a product class using official_code" do
      {_full_code, official_code} = get_codes_at_level(3)

      conn =
        conn(:get, "/api/product_classes/by_code/#{official_code}/ancestors")
        |> Router.call(@opts)

      assert conn.status == 200
      # Level 3 item should have 2 ancestors (levels 1 and 2)
      assert %{"data" => [_, _], "count" => 2} = JSON.decode!(conn.resp_body)
    end
  end

  describe "GET /api/product_classes/by_code/:code/full_path" do
    test "returns full path from root to product class using full_code" do
      code = get_code_at_level(3)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}/full_path")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"data" => path, "count" => 3} = JSON.decode!(conn.resp_body)
      levels = Enum.map(path, & &1["level"])

      assert levels == [1, 2, 3]
    end

    test "returns full path from root to product class using official_code" do
      {_full_code, official_code} = get_codes_at_level(3)

      conn =
        conn(:get, "/api/product_classes/by_code/#{official_code}/full_path")
        |> Router.call(@opts)

      assert conn.status == 200

      %{"data" => path, "count" => 3} = JSON.decode!(conn.resp_body)
      levels = Enum.map(path, & &1["level"])

      assert levels == [1, 2, 3]
    end
  end

  describe "GET /api/product_classes/by_code/:code/parent" do
    test "returns parent of a product class using full_code" do
      code = get_code_at_level(2)

      conn =
        conn(:get, "/api/product_classes/by_code/#{code}/parent")
        |> Router.call(@opts)

      assert conn.status == 200
      assert %{"data" => %{"level" => 1}} = JSON.decode!(conn.resp_body)
    end

    test "returns parent of a product class using official_code" do
      {_full_code, official_code} = get_codes_at_level(3)

      conn =
        conn(:get, "/api/product_classes/by_code/#{official_code}/parent")
        |> Router.call(@opts)

      assert conn.status == 200
      # Level 3 item's parent should be at level 2
      assert %{"data" => %{"level" => 2}} = JSON.decode!(conn.resp_body)
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

  describe "full_code vs official_code consistency" do
    test "both code formats return the same product class" do
      {full_code, official_code} = get_codes_at_level(4)

      full_code_response =
        conn(:get, "/api/product_classes/by_code/#{full_code}")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      official_code_response =
        conn(:get, "/api/product_classes/by_code/#{official_code}")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      assert full_code_response == official_code_response
    end

    test "both code formats return the same children" do
      {full_code, official_code} = get_codes_at_level(2)

      full_code_children =
        conn(:get, "/api/product_classes/by_code/#{full_code}/children")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      official_code_children =
        conn(:get, "/api/product_classes/by_code/#{official_code}/children")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      assert full_code_children == official_code_children
    end

    test "both code formats return the same descendants" do
      {full_code, official_code} = get_codes_at_level(2)

      full_code_descendants =
        conn(:get, "/api/product_classes/by_code/#{full_code}/descendants?limit=10")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      official_code_descendants =
        conn(:get, "/api/product_classes/by_code/#{official_code}/descendants?limit=10")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      assert full_code_descendants == official_code_descendants
    end

    test "both code formats return the same ancestors" do
      {full_code, official_code} = get_codes_at_level(4)

      full_code_ancestors =
        conn(:get, "/api/product_classes/by_code/#{full_code}/ancestors")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      official_code_ancestors =
        conn(:get, "/api/product_classes/by_code/#{official_code}/ancestors")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      assert full_code_ancestors == official_code_ancestors
    end

    test "both code formats return the same full_path" do
      {full_code, official_code} = get_codes_at_level(4)

      full_code_path =
        conn(:get, "/api/product_classes/by_code/#{full_code}/full_path")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      official_code_path =
        conn(:get, "/api/product_classes/by_code/#{official_code}/full_path")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      assert full_code_path == official_code_path
    end

    test "both code formats return the same parent" do
      {full_code, official_code} = get_codes_at_level(3)

      full_code_parent =
        conn(:get, "/api/product_classes/by_code/#{full_code}/parent")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      official_code_parent =
        conn(:get, "/api/product_classes/by_code/#{official_code}/parent")
        |> Router.call(@opts)
        |> Map.get(:resp_body)
        |> JSON.decode!()

      assert full_code_parent == official_code_parent
    end
  end
end
