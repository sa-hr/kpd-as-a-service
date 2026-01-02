defmodule KpdAsAService.ProductClass do
  @moduledoc """
  Ecto schema for KPD (Klasifikacija Proizvoda po Djelatnostima) product classes.

  This represents a hierarchical classification system with 6 levels:
  - Level 1: Section (e.g., "A")
  - Level 2: Division (e.g., "A.01")
  - Level 3: Group (e.g., "A.01.1")
  - Level 4: Class (e.g., "A.01.1.1")
  - Level 5: Category (e.g., "A.01.1.1.1")
  - Level 6: Subcategory (e.g., "A.01.1.1.1.1")

  The `path` field uses dot-separated segments for hierarchical queries.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          code: String.t(),
          path: String.t(),
          name_hr: String.t(),
          name_en: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          level: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "product_classes" do
    field(:code, :string)
    field(:path, :string)
    field(:name_hr, :string)
    field(:name_en, :string)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:level, :integer)

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(code path name_hr name_en level)a
  @optional_fields ~w(start_date end_date)a

  @doc """
  Creates a changeset for a ProductClass.
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(product_class, attrs) do
    product_class
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:level, 1..6)
    |> validate_path_matches_level()
    |> unique_constraint(:code)
  end

  @doc """
  Returns the parent path for a given path.
  Returns nil for level 1 (root) entries.

  ## Examples

      iex> ProductClass.parent_path("A.01.1.1")
      "A.01.1"

      iex> ProductClass.parent_path("A")
      nil

  """
  @spec parent_path(String.t()) :: String.t() | nil
  def parent_path(path) when is_binary(path) do
    segments = String.split(path, ".")

    case segments do
      [_single] -> nil
      multiple -> multiple |> Enum.drop(-1) |> Enum.join(".")
    end
  end

  @doc """
  Returns the path prefix pattern for finding all children.

  ## Examples

      iex> ProductClass.children_path_prefix("A.01")
      "A.01.%"

  """
  @spec children_path_prefix(String.t()) :: String.t()
  def children_path_prefix(path) when is_binary(path) do
    "#{path}.%"
  end

  @doc """
  Returns the path prefix pattern for finding all ancestors.
  Returns a list of ancestor paths from root to immediate parent.

  ## Examples

      iex> ProductClass.ancestor_paths("A.01.1.1")
      ["A", "A.01", "A.01.1"]

  """
  @spec ancestor_paths(String.t()) :: [String.t()]
  def ancestor_paths(path) when is_binary(path) do
    segments = String.split(path, ".")

    segments
    |> Enum.drop(-1)
    |> Enum.scan(fn segment, acc -> "#{acc}.#{segment}" end)
    |> case do
      [] -> []
      paths -> paths
    end
  end

  # Alternative implementation using reduce
  @doc """
  Returns all ancestor paths from root to immediate parent.

  ## Examples

      iex> ProductClass.build_ancestor_paths("A.01.1.1.1.1")
      ["A", "A.01", "A.01.1", "A.01.1.1", "A.01.1.1.1"]

  """
  @spec build_ancestor_paths(String.t()) :: [String.t()]
  def build_ancestor_paths(path) when is_binary(path) do
    segments = String.split(path, ".")

    {ancestors, _} =
      segments
      |> Enum.drop(-1)
      |> Enum.reduce({[], nil}, fn segment, {acc, current} ->
        new_path = if current, do: "#{current}.#{segment}", else: segment
        {acc ++ [new_path], new_path}
      end)

    ancestors
  end

  # Private functions

  defp validate_path_matches_level(changeset) do
    path = get_field(changeset, :path)
    level = get_field(changeset, :level)

    if path && level do
      actual_level = path |> String.split(".") |> length()

      if actual_level == level do
        changeset
      else
        add_error(
          changeset,
          :path,
          "path has #{actual_level} segments but level is #{level}"
        )
      end
    else
      changeset
    end
  end
end
