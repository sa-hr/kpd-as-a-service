defmodule KPD.ImporterTest do
  use KPD.DataCase, async: true

  alias KPD.Importer
  alias KPD.ProductClass
  alias KPD.Repo

  describe "transform_code_to_path/1" do
    test "transforms level 1 code (letter only)" do
      assert Importer.transform_code_to_path("A") == "A"
      assert Importer.transform_code_to_path("B") == "B"
      assert Importer.transform_code_to_path("C") == "C"
    end

    test "transforms level 2 code (letter + 2 digits)" do
      assert Importer.transform_code_to_path("A01") == "A.01"
      assert Importer.transform_code_to_path("B05") == "B.05"
      assert Importer.transform_code_to_path("B25") == "B.25"
      assert Importer.transform_code_to_path("C10") == "C.10"
    end

    test "transforms level 3 code" do
      assert Importer.transform_code_to_path("A01.1") == "A.01.1"
      assert Importer.transform_code_to_path("C10.9") == "C.10.9"
    end

    test "transforms level 4 code" do
      assert Importer.transform_code_to_path("A01.11") == "A.01.1.1"
      assert Importer.transform_code_to_path("C10.12") == "C.10.1.2"
    end

    test "transforms level 5 code" do
      assert Importer.transform_code_to_path("A01.11.1") == "A.01.1.1.1"
      assert Importer.transform_code_to_path("C10.12.4") == "C.10.1.2.4"
    end

    test "transforms level 6 code" do
      assert Importer.transform_code_to_path("A01.11.11") == "A.01.1.1.1.1"
      assert Importer.transform_code_to_path("C10.12.50") == "C.10.1.2.5.0"
    end

    test "handles whitespace" do
      assert Importer.transform_code_to_path("  A01  ") == "A.01"
      assert Importer.transform_code_to_path(" A01.11.11 ") == "A.01.1.1.1.1"
      assert Importer.transform_code_to_path("  C10.12.4  ") == "C.10.1.2.4"
    end
  end

  describe "validate_level/2" do
    test "returns :ok when path matches expected level" do
      assert Importer.validate_level("A", 1) == :ok
      assert Importer.validate_level("C.10", 2) == :ok
      assert Importer.validate_level("A.01.1", 3) == :ok
      assert Importer.validate_level("A.01.1.1", 4) == :ok
      assert Importer.validate_level("A.01.1.1.1", 5) == :ok
      assert Importer.validate_level("C.10.1.2.5.0", 6) == :ok
    end

    test "returns error when path does not match expected level" do
      assert {:error, msg} = Importer.validate_level("A.01", 3)
      assert msg == "Level mismatch: expected 3 levels, got 2"
    end

    test "returns error for level mismatch - too few levels" do
      assert {:error, msg} = Importer.validate_level("A", 2)
      assert msg == "Level mismatch: expected 2 levels, got 1"
    end

    test "returns error for level mismatch - too many levels" do
      assert {:error, msg} = Importer.validate_level("A.01.1.1.1.1", 5)
      assert msg == "Level mismatch: expected 5 levels, got 6"
    end
  end

  describe "load_from_file/2" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      # Create a temporary CSV file for testing
      csv_content = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      A,01.01.2025, ,PROIZVODI POLJOPRIVREDE, ,PRODUCTS OF AGRICULTURE, ,1,A
      01,01.01.2025, ,Biljni i stočarski proizvodi, ,Products of agriculture, ,2,A01
      01.1,01.01.2025, ,Jednogodišnji usjevi, ,Non-perennial crops, ,3,A01.1
      01.11,01.01.2025, ,Žitarice, ,Cereals, ,4,A01.11
      01.11.1,01.01.2025, ,Pšenica, ,Wheat, ,5,A01.11.1
      01.11.11,01.01.2025, ,Tvrda pšenica, ,Durum wheat, ,6,A01.11.11
      """

      csv_path = Path.join(tmp_dir, "test_kpd.csv")
      File.write!(csv_path, csv_content)

      {:ok, csv_path: csv_path}
    end

    test "loads all levels (1-6) from CSV file", %{csv_path: csv_path} do
      result = Importer.load_from_file(csv_path)

      assert {:ok, %{processed: 6, errors: []}} = result

      # Verify level 1
      level1 = Repo.get_by(ProductClass, code: "A")
      assert level1.code == "A"
      assert level1.path == "A"
      assert level1.level == 1
      assert level1.name_hr == "PROIZVODI POLJOPRIVREDE"
      assert level1.name_en == "PRODUCTS OF AGRICULTURE"
      assert level1.start_date == ~D[2025-01-01]
      assert is_nil(level1.end_date)

      # Verify level 2
      level2 = Repo.get_by(ProductClass, code: "A01")
      assert level2.path == "A.01"
      assert level2.level == 2
      assert level2.name_hr == "Biljni i stočarski proizvodi"

      # Verify level 3
      level3 = Repo.get_by(ProductClass, code: "A01.1")
      assert level3.path == "A.01.1"
      assert level3.level == 3

      # Verify level 4
      level4 = Repo.get_by(ProductClass, code: "A01.11")
      assert level4.path == "A.01.1.1"
      assert level4.level == 4

      # Verify level 5
      level5 = Repo.get_by(ProductClass, code: "A01.11.1")
      assert level5.path == "A.01.1.1.1"
      assert level5.level == 5

      # Verify level 6
      level6 = Repo.get_by(ProductClass, code: "A01.11.11")
      assert level6.path == "A.01.1.1.1.1"
      assert level6.level == 6
      assert level6.name_en == "Durum wheat"
    end

    test "updates existing records on conflict", %{csv_path: csv_path, tmp_dir: tmp_dir} do
      # First load
      {:ok, %{processed: 6}} = Importer.load_from_file(csv_path)

      # Modify CSV with updated data
      updated_csv = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      A,01.01.2025, ,UPDATED NAME HR, ,UPDATED NAME EN, ,1,A
      """

      updated_path = Path.join(tmp_dir, "test_kpd_updated.csv")
      File.write!(updated_path, updated_csv)

      # Second load should update
      {:ok, %{processed: 1}} = Importer.load_from_file(updated_path)

      # Verify update
      updated = Repo.get_by(ProductClass, code: "A")
      assert updated.name_hr == "UPDATED NAME HR"
      assert updated.name_en == "UPDATED NAME EN"
    end

    test "handles CSV with end dates", %{tmp_dir: tmp_dir} do
      csv_with_end_date = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      X,01.01.2025,31.12.2025,Test Product,  ,Test Product EN, ,1,X
      """

      csv_path = Path.join(tmp_dir, "test_kpd_end_date.csv")
      File.write!(csv_path, csv_with_end_date)

      {:ok, %{processed: 1}} = Importer.load_from_file(csv_path)

      record = Repo.get_by(ProductClass, code: "X")
      assert record.start_date == ~D[2025-01-01]
      assert record.end_date == ~D[2025-12-31]
    end

    test "returns errors for invalid rows", %{tmp_dir: tmp_dir} do
      invalid_csv = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      Y,invalid-date, ,Test, ,Test, ,1,Y
      """

      csv_path = Path.join(tmp_dir, "test_kpd_invalid.csv")
      File.write!(csv_path, invalid_csv)

      {:ok, result} = Importer.load_from_file(csv_path)

      assert result.processed == 0
      assert length(result.errors) == 1
      assert [{1, _error_msg}] = result.errors
    end

    test "validates level mismatch", %{tmp_dir: tmp_dir} do
      # Level says 2 but code only has 1 level
      mismatch_csv = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      Z,01.01.2025, ,Test, ,Test, ,2,Z
      """

      csv_path = Path.join(tmp_dir, "test_kpd_mismatch.csv")
      File.write!(csv_path, mismatch_csv)

      {:ok, result} = Importer.load_from_file(csv_path)

      assert result.processed == 0
      assert length(result.errors) == 1
      assert [{1, "Level mismatch: expected 2 levels, got 1"}] = result.errors
    end

    test "handles UTF-8 with BOM correctly", %{tmp_dir: tmp_dir} do
      # Create CSV with BOM
      csv_with_bom =
        <<0xEF, 0xBB, 0xBF>> <>
          """
          Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
          W,01.01.2025, ,Čćžšđ, ,Special chars, ,1,W
          """

      csv_path = Path.join(tmp_dir, "test_kpd_bom.csv")
      File.write!(csv_path, csv_with_bom)

      {:ok, %{processed: 1}} = Importer.load_from_file(csv_path)

      record = Repo.get_by(ProductClass, code: "W")
      assert record.name_hr == "Čćžšđ"
    end

    test "can skip conflicts with :nothing option", %{csv_path: csv_path} do
      # First load
      {:ok, %{processed: 6}} = Importer.load_from_file(csv_path)

      # Second load with on_conflict: :nothing should skip all existing records
      {:ok, result} = Importer.load_from_file(csv_path, on_conflict: :nothing)

      # All records already exist, so processed count is 0
      assert result.processed == 0
      assert result.errors == []
    end

    test "loads from gzipped CSV file", %{tmp_dir: tmp_dir} do
      csv_content = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      H,01.01.2025, ,Gzipped Product, ,Gzipped Product EN, ,1,H
      01,01.01.2025, ,Gzipped Level 2, ,Gzipped Level 2 EN, ,2,H01
      """

      # Create gzipped CSV file
      compressed = :zlib.gzip(csv_content)
      gz_path = Path.join(tmp_dir, "test_kpd.csv.gz")
      File.write!(gz_path, compressed)

      # Load from gzipped file
      {:ok, %{processed: 2, errors: []}} = Importer.load_from_file(gz_path)

      # Verify records were inserted
      level1 = Repo.get_by(ProductClass, code: "H")
      assert level1.code == "H"
      assert level1.path == "H"
      assert level1.level == 1
      assert level1.name_hr == "Gzipped Product"
      assert level1.name_en == "Gzipped Product EN"

      level2 = Repo.get_by(ProductClass, code: "H01")
      assert level2.code == "H01"
      assert level2.path == "H.01"
      assert level2.level == 2
      assert level2.name_hr == "Gzipped Level 2"
    end
  end

  describe "edge cases" do
    @describetag :tmp_dir

    test "handles empty end date field", %{tmp_dir: tmp_dir} do
      csv_content = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      F,01.01.2025, ,Test, ,Test, ,1,F
      """

      csv_path = Path.join(tmp_dir, "test_kpd_empty.csv")
      File.write!(csv_path, csv_content)

      {:ok, %{processed: 1}} = Importer.load_from_file(csv_path)

      record = Repo.get_by(ProductClass, code: "F")
      assert is_nil(record.end_date)
    end

    test "trims whitespace from text fields", %{tmp_dir: tmp_dir} do
      csv_content = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      G,01.01.2025, ,  Whitespace Test  , ,  Whitespace Test EN  , ,1,  G
      """

      csv_path = Path.join(tmp_dir, "test_kpd_whitespace.csv")
      File.write!(csv_path, csv_content)

      {:ok, %{processed: 1}} = Importer.load_from_file(csv_path)

      record = Repo.get_by(ProductClass, code: "G")
      assert record.code == "G"
      assert record.name_hr == "Whitespace Test"
      assert record.name_en == "Whitespace Test EN"
    end

    test "handles codes with zeros", %{tmp_dir: tmp_dir} do
      csv_content = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      01.11.20,01.01.2025, ,Kukuruz, ,Maize, ,6,V01.11.20
      01.11.50,01.01.2025, ,Slama, ,Straw, ,6,V01.11.50
      """

      csv_path = Path.join(tmp_dir, "test_kpd_zeros.csv")
      File.write!(csv_path, csv_content)

      {:ok, %{processed: 2}} = Importer.load_from_file(csv_path)

      record1 = Repo.get_by(ProductClass, code: "V01.11.20")
      assert record1.path == "V.01.1.1.2.0"
      assert record1.level == 6

      record2 = Repo.get_by(ProductClass, code: "V01.11.50")
      assert record2.path == "V.01.1.1.5.0"
      assert record2.level == 6
    end
  end

  describe "rebuild_fts_index/0" do
    @describetag :tmp_dir

    test "rebuilds the FTS index", %{tmp_dir: tmp_dir} do
      csv_content = """
      Službena šifra,Datum početka,Datum završetka,Službeni naziv HR,Kratki naziv HR,Službeni naziv EN,Kratki naziv EN,Broj razine,Potpuna šifra
      R,01.01.2025, ,Rebuild Test HR, ,Rebuild Test EN, ,1,R
      """

      csv_path = Path.join(tmp_dir, "test_rebuild.csv")
      File.write!(csv_path, csv_content)

      {:ok, %{processed: 1}} = Importer.load_from_file(csv_path)

      # Rebuild should not raise
      assert :ok = Importer.rebuild_fts_index()

      # Verify the record exists in main table after rebuild
      record = Repo.get_by(ProductClass, code: "R")
      assert record != nil
      assert record.name_hr == "Rebuild Test HR"

      # Verify FTS table has entries (just check it's not empty)
      result = Repo.query!("SELECT COUNT(*) FROM product_classes_fts")
      [[count]] = result.rows
      assert count > 0
    end
  end
end
