defmodule KPDTest do
  use KPD.DataCase, async: false

  alias KPD.ProductClass

  # Tests use the seeded data from priv/data/kpd-2025.csv.gz
  # which is loaded in test_helper.exs via KPD.TestSeeds
  #
  # Known stable data points from KPD 2025:
  # - 22 root sections (A through V)
  # - Section A: "PROIZVODI POLJOPRIVREDE, ŠUMARSTVA I RIBARSTVA"
  # - A01: "Products of agriculture, hunting and related services"
  # - A01.1: "Non-perennial crops"
  # - A01.11: "Cereals (except rice), leguminous crops and oil seeds"
  # - A01.11.1: "Wheat"
  # - A01.11.11: "Durum wheat"

  describe "list/1" do
    test "lists product classes ordered by path with default limit of 100" do
      results = KPD.list()

      assert length(results) == 100

      # First result should be section A (first alphabetically)
      [first | _] = results
      assert %ProductClass{full_code: "A", level: 1, path: "A"} = first

      # Results should be ordered by path
      paths = Enum.map(results, & &1.path)
      assert paths == Enum.sort(paths)
    end

    test "lists product classes filtered by level" do
      results = KPD.list(level: 1)

      # There are exactly 22 root sections in KPD 2025
      assert length(results) == 22
      assert Enum.all?(results, &(&1.level == 1))

      # Verify known sections exist
      codes = Enum.map(results, & &1.full_code)
      assert "A" in codes
      assert "B" in codes
      assert "C" in codes
    end

    test "respects limit and offset for pagination" do
      page1 = KPD.list(limit: 5, offset: 0)
      page2 = KPD.list(limit: 5, offset: 5)

      assert length(page1) == 5
      assert length(page2) == 5

      # Pages should not overlap
      page1_codes = Enum.map(page1, & &1.full_code)
      page2_codes = Enum.map(page2, & &1.full_code)
      assert Enum.all?(page2_codes, fn code -> code not in page1_codes end)
    end
  end

  describe "list_roots/1" do
    test "returns all 22 root sections" do
      roots = KPD.list_roots()

      assert length(roots) == 22
      assert Enum.all?(roots, &(&1.level == 1))
      assert Enum.all?(roots, &(String.length(&1.path) == 1))

      # Verify first and last known sections
      codes = Enum.map(roots, & &1.full_code)
      assert List.first(codes) == "A"
      assert List.last(codes) == "V"
    end
  end

  describe "get_by_code/1" do
    test "returns section A with correct attributes" do
      assert %ProductClass{
               full_code: "A",
               path: "A",
               level: 1,
               name_hr: "PROIZVODI POLJOPRIVREDE, ŠUMARSTVA I RIBARSTVA",
               name_en: "PRODUCTS OF AGRICULTURE, FORESTRY AND FISHING"
             } = KPD.get_by_code("A")
    end

    test "returns A01 division with correct attributes" do
      assert %ProductClass{
               full_code: "A01",
               path: "A.01",
               level: 2,
               name_en: "Products of agriculture, hunting and related services"
             } = KPD.get_by_code("A01")
    end

    test "returns A01.11.11 (level 6) with correct attributes" do
      assert %ProductClass{
               full_code: "A01.11.11",
               path: "A.01.1.1.1.1",
               level: 6,
               name_hr: "Tvrda pšenica",
               name_en: "Durum wheat"
             } = KPD.get_by_code("A01.11.11")
    end

    test "returns nil for non-existent code" do
      assert KPD.get_by_code("NONEXISTENT999") == nil
    end

    # Tests for official codes (without letter prefix)
    test "returns A01 division using official code '01'" do
      assert %ProductClass{
               full_code: "A01",
               official_code: "01",
               path: "A.01",
               level: 2,
               name_en: "Products of agriculture, hunting and related services"
             } = KPD.get_by_code("01")
    end

    test "returns A01.11.11 (level 6) using official code '01.11.11'" do
      assert %ProductClass{
               full_code: "A01.11.11",
               official_code: "01.11.11",
               path: "A.01.1.1.1.1",
               level: 6,
               name_hr: "Tvrda pšenica",
               name_en: "Durum wheat"
             } = KPD.get_by_code("01.11.11")
    end

    test "returns A01.1 (level 3) using official code '01.1'" do
      assert %ProductClass{
               full_code: "A01.1",
               official_code: "01.1",
               path: "A.01.1",
               level: 3,
               name_en: "Non-perennial crops"
             } = KPD.get_by_code("01.1")
    end

    test "returns nil for non-existent official code" do
      assert KPD.get_by_code("99.99.99") == nil
    end

    test "full code and official code return the same product class" do
      full_result = KPD.get_by_code("A01.11.11")
      official_result = KPD.get_by_code("01.11.11")

      assert full_result.full_code == official_result.full_code
      assert full_result.official_code == official_result.official_code
    end
  end

  describe "get_by_code!/1" do
    test "returns product class when found" do
      assert %ProductClass{full_code: "A"} = KPD.get_by_code!("A")
    end

    test "raises Ecto.NoResultsError when not found" do
      assert_raise Ecto.NoResultsError, fn ->
        KPD.get_by_code!("NONEXISTENT999")
      end
    end

    # Tests for official codes (without letter prefix)
    test "returns product class when found using official code '01'" do
      assert %ProductClass{full_code: "A01", official_code: "01"} = KPD.get_by_code!("01")
    end

    test "returns product class when found using official code '01.11.11'" do
      assert %ProductClass{full_code: "A01.11.11", official_code: "01.11.11"} =
               KPD.get_by_code!("01.11.11")
    end

    test "raises Ecto.NoResultsError when official code not found" do
      assert_raise Ecto.NoResultsError, fn ->
        KPD.get_by_code!("99.99.99")
      end
    end
  end

  describe "get_children/2" do
    test "returns direct children of section A" do
      children = KPD.get_children("A")

      # Section A has 3 divisions: A01, A02, A03
      assert length(children) == 3
      assert Enum.all?(children, &(&1.level == 2))

      codes = Enum.map(children, & &1.full_code)
      assert codes == ["A01", "A02", "A03"]
    end

    test "returns direct children of A01 division" do
      children = KPD.get_children("A.01")

      # A01 has 6 groups: A01.1, A01.2, A01.3, A01.4, A01.6, A01.7 (no A01.5)
      assert length(children) == 6
      assert Enum.all?(children, &(&1.level == 3))

      codes = Enum.map(children, & &1.full_code)
      assert codes == ["A01.1", "A01.2", "A01.3", "A01.4", "A01.6", "A01.7"]
    end

    test "returns empty list for leaf node A01.11.11" do
      children = KPD.get_children("A.01.1.1.1.1")
      assert children == []
    end
  end

  describe "get_descendants/2" do
    test "returns all descendants of A01.11 (cereals)" do
      descendants = KPD.get_descendants("A.01.1.1")

      # Should have level 5 and level 6 descendants
      levels = descendants |> Enum.map(& &1.level) |> Enum.uniq() |> Enum.sort()
      assert levels == [5, 6]

      # All descendants should have A.01.1.1. prefix
      assert Enum.all?(descendants, &String.starts_with?(&1.path, "A.01.1.1."))

      # Should include wheat (A01.11.1) and durum wheat (A01.11.11)
      codes = Enum.map(descendants, & &1.full_code)
      assert "A01.11.1" in codes
      assert "A01.11.11" in codes
    end

    test "returns empty list for leaf node" do
      descendants = KPD.get_descendants("A.01.1.1.1.1")
      assert descendants == []
    end
  end

  describe "get_parent/1" do
    test "returns parent of A01 division" do
      parent = KPD.get_parent("A.01")

      assert %ProductClass{full_code: "A", level: 1, path: "A"} = parent
    end

    test "returns parent of A01.11.11 (durum wheat)" do
      parent = KPD.get_parent("A.01.1.1.1.1")

      assert %ProductClass{
               full_code: "A01.11.1",
               level: 5,
               path: "A.01.1.1.1",
               name_en: "Wheat"
             } = parent
    end

    test "returns nil for root section A" do
      assert KPD.get_parent("A") == nil
    end
  end

  describe "get_ancestors/1" do
    test "returns all ancestors of A01.11.11 (durum wheat)" do
      ancestors = KPD.get_ancestors("A.01.1.1.1.1")

      assert length(ancestors) == 5

      codes = Enum.map(ancestors, & &1.full_code)
      assert codes == ["A", "A01", "A01.1", "A01.11", "A01.11.1"]

      levels = Enum.map(ancestors, & &1.level)
      assert levels == [1, 2, 3, 4, 5]
    end

    test "returns 3 ancestors for level 4 entry A01.11" do
      ancestors = KPD.get_ancestors("A.01.1.1")

      assert length(ancestors) == 3
      assert Enum.map(ancestors, & &1.level) == [1, 2, 3]
    end

    test "returns empty list for root section" do
      ancestors = KPD.get_ancestors("A")
      assert ancestors == []
    end
  end

  describe "get_full_path/1" do
    test "returns full path from root to A01.11 (cereals)" do
      full_path = KPD.get_full_path("A.01.1.1")

      assert length(full_path) == 4

      codes = Enum.map(full_path, & &1.full_code)
      assert codes == ["A", "A01", "A01.1", "A01.11"]

      # Last entry should be the target
      assert %ProductClass{full_code: "A01.11", level: 4} = List.last(full_path)
    end

    test "returns single entry for root section" do
      full_path = KPD.get_full_path("A")

      assert length(full_path) == 1
      assert [%ProductClass{full_code: "A", level: 1}] = full_path
    end
  end

  describe "search/2" do
    test "finds 'Pšenica' (wheat) in Croatian names" do
      results = KPD.search("Pšenica", lang: :hr)

      # Should find A01.11.1 (Wheat category)
      codes = Enum.map(results, & &1.full_code)
      assert "A01.11.1" in codes
    end

    test "finds 'Durum wheat' in English names" do
      results = KPD.search("Durum wheat", lang: :en)

      codes = Enum.map(results, & &1.full_code)
      assert "A01.11.11" in codes
    end

    test "searches both languages by default" do
      results = KPD.search("wheat")

      # Should find wheat-related entries
      codes = Enum.map(results, & &1.full_code)
      assert "A01.11.1" in codes or "A01.11.11" in codes
    end

    test "filters search results by level" do
      results = KPD.search("product", lang: :en, level: 1)

      assert Enum.all?(results, &(&1.level == 1))
    end

    test "respects limit parameter" do
      results = KPD.search("product", lang: :en, limit: 3)
      assert length(results) <= 3
    end
  end

  describe "search_by_code/2" do
    test "finds all entries starting with A01" do
      results = KPD.search_by_code("A01")

      assert Enum.all?(results, &String.starts_with?(&1.full_code, "A01"))

      # Should include A01 itself and its descendants
      codes = Enum.map(results, & &1.full_code)
      assert "A01" in codes
      assert "A01.1" in codes
    end

    test "returns empty list for non-matching prefix" do
      results = KPD.search_by_code("ZZZ999")
      assert results == []
    end

    test "respects limit parameter" do
      results = KPD.search_by_code("A", limit: 5)
      assert length(results) == 5
    end
  end

  describe "count/1" do
    test "returns total count of 5828 entries" do
      # KPD 2025 has exactly 5828 product classes
      assert KPD.count() == 5828
    end

    test "returns correct counts by level" do
      assert KPD.count(level: 1) == 22
      assert KPD.count(level: 2) == 87
      assert KPD.count(level: 3) == 284
      assert KPD.count(level: 4) == 644
      assert KPD.count(level: 5) == 1432
      assert KPD.count(level: 6) == 3359
    end

    test "level counts sum to total" do
      total = KPD.count()

      level_sum =
        1..6
        |> Enum.map(&KPD.count(level: &1))
        |> Enum.sum()

      assert level_sum == total
    end
  end

  describe "ProductClass.parent_path/1" do
    test "returns parent path for multi-segment paths" do
      assert ProductClass.parent_path("A.01.1.1") == "A.01.1"
      assert ProductClass.parent_path("A.01.1") == "A.01"
      assert ProductClass.parent_path("A.01") == "A"
    end

    test "returns nil for single-segment (root) paths" do
      assert ProductClass.parent_path("A") == nil
      assert ProductClass.parent_path("B") == nil
    end
  end

  describe "ProductClass.build_ancestor_paths/1" do
    test "builds ancestor paths for 4-level path" do
      assert ProductClass.build_ancestor_paths("A.01.1.1") == ["A", "A.01", "A.01.1"]
    end

    test "builds ancestor paths for 6-level path" do
      paths = ProductClass.build_ancestor_paths("A.01.1.1.1.1")
      assert paths == ["A", "A.01", "A.01.1", "A.01.1.1", "A.01.1.1.1"]
    end

    test "returns empty list for root path" do
      assert ProductClass.build_ancestor_paths("A") == []
    end
  end

  describe "ProductClass.children_path_prefix/1" do
    test "returns correct LIKE pattern" do
      assert ProductClass.children_path_prefix("A") == "A.%"
      assert ProductClass.children_path_prefix("A.01") == "A.01.%"
      assert ProductClass.children_path_prefix("A.01.1.1.1") == "A.01.1.1.1.%"
    end
  end
end
