defmodule KpdAsAService.Repo.Migrations.CreateProductClasses do
  use Ecto.Migration

  def change do
    create table(:product_classes) do
      add(:code, :string, null: false)
      add(:path, :string, null: false)
      add(:name_hr, :string, null: false)
      add(:name_en, :string, null: false)
      add(:start_date, :date)
      add(:end_date, :date)
      add(:level, :integer, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:product_classes, [:code]))
    create(index(:product_classes, [:path]))
    create(index(:product_classes, [:level]))
    create(index(:product_classes, [:name_hr]))
    create(index(:product_classes, [:name_en]))
  end
end
