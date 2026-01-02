defmodule KpdAsAService.TestSeeds do
  @moduledoc """
  Module for seeding test data from CSV files.

  This module is used to populate the test database with real KPD data
  before running the test suite.
  """

  alias KpdAsAService.Importer
  alias KpdAsAService.Repo

  @doc """
  Seeds the test database with real KPD data from the kpd-2025.csv.gz file.

  This function should be called once at the beginning of the test suite
  to populate the database with test data.
  """
  def seed! do
    csv_path = Path.expand("../../priv/data/kpd-2025.csv.gz", __DIR__)

    if !File.exists?(csv_path) do
      raise "Test seed file not found: #{csv_path}"
    end

    case Importer.load_from_file(csv_path) do
      {:ok, %{processed: count, errors: []}} ->
        IO.puts("Seeded #{count} KPD product classes for tests")
        :ok

      {:ok, %{processed: count, errors: errors}} ->
        IO.puts("Seeded #{count} KPD product classes with #{length(errors)} errors")
        :ok

      {:error, reason} ->
        raise "Failed to seed test data: #{inspect(reason)}"
    end
  end

  @doc """
  Clears all product classes from the database.

  Useful for resetting the database between test runs.
  """
  def clear! do
    Repo.delete_all(KpdAsAService.ProductClass)
    :ok
  end

  @doc """
  Reseeds the database by clearing and then seeding.
  """
  def reseed! do
    clear!()
    seed!()
  end
end
