defmodule KPD.Repo.Migrations.CreateFtsSearch do
  use Ecto.Migration

  def up do
    # Create FTS5 virtual table with trigram tokenizer for fuzzy search
    # The trigram tokenizer was added in SQLite 3.34.0
    execute("""
    CREATE VIRTUAL TABLE product_classes_fts USING fts5(
      code,
      name_hr,
      name_en,
      content='product_classes',
      content_rowid='id',
      tokenize='trigram'
    );
    """)

    # Populate the FTS table with existing data
    execute("""
    INSERT INTO product_classes_fts(rowid, code, name_hr, name_en)
    SELECT id, code, name_hr, name_en FROM product_classes;
    """)

    # Create triggers to keep FTS index in sync with main table

    # Trigger for INSERT
    execute("""
    CREATE TRIGGER product_classes_fts_insert AFTER INSERT ON product_classes BEGIN
      INSERT INTO product_classes_fts(rowid, code, name_hr, name_en)
      VALUES (NEW.id, NEW.code, NEW.name_hr, NEW.name_en);
    END;
    """)

    # Trigger for DELETE
    execute("""
    CREATE TRIGGER product_classes_fts_delete AFTER DELETE ON product_classes BEGIN
      INSERT INTO product_classes_fts(product_classes_fts, rowid, code, name_hr, name_en)
      VALUES ('delete', OLD.id, OLD.code, OLD.name_hr, OLD.name_en);
    END;
    """)

    # Trigger for UPDATE
    execute("""
    CREATE TRIGGER product_classes_fts_update AFTER UPDATE ON product_classes BEGIN
      INSERT INTO product_classes_fts(product_classes_fts, rowid, code, name_hr, name_en)
      VALUES ('delete', OLD.id, OLD.code, OLD.name_hr, OLD.name_en);
      INSERT INTO product_classes_fts(rowid, code, name_hr, name_en)
      VALUES (NEW.id, NEW.code, NEW.name_hr, NEW.name_en);
    END;
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS product_classes_fts_update;")
    execute("DROP TRIGGER IF EXISTS product_classes_fts_delete;")
    execute("DROP TRIGGER IF EXISTS product_classes_fts_insert;")
    execute("DROP TABLE IF EXISTS product_classes_fts;")
  end
end
