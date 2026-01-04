defmodule KPD.Repo.Migrations.CreateProductClasses do
  use Ecto.Migration

  def up do
    # Create the product_classes table with full_code as primary key
    execute("""
    CREATE TABLE product_classes (
      full_code TEXT PRIMARY KEY NOT NULL,
      official_code TEXT,
      path TEXT NOT NULL,
      name_hr TEXT NOT NULL,
      name_en TEXT NOT NULL,
      start_date DATE,
      end_date DATE,
      level INTEGER NOT NULL
    );
    """)

    # Create indexes for fast lookups
    execute("CREATE INDEX product_classes_official_code_index ON product_classes(official_code);")
    execute("CREATE INDEX product_classes_path_index ON product_classes(path);")
    execute("CREATE INDEX product_classes_level_index ON product_classes(level);")
    execute("CREATE INDEX product_classes_name_hr_index ON product_classes(name_hr);")
    execute("CREATE INDEX product_classes_name_en_index ON product_classes(name_en);")

    # Create FTS5 virtual table with trigram tokenizer for fuzzy search
    execute("""
    CREATE VIRTUAL TABLE product_classes_fts USING fts5(
      full_code,
      name_hr,
      name_en,
      content='product_classes',
      content_rowid='rowid',
      tokenize='trigram'
    );
    """)

    # Create triggers to keep FTS index in sync with main table

    # Trigger for INSERT
    execute("""
    CREATE TRIGGER product_classes_fts_insert AFTER INSERT ON product_classes BEGIN
      INSERT INTO product_classes_fts(rowid, full_code, name_hr, name_en)
      VALUES (NEW.rowid, NEW.full_code, NEW.name_hr, NEW.name_en);
    END;
    """)

    # Trigger for DELETE
    execute("""
    CREATE TRIGGER product_classes_fts_delete AFTER DELETE ON product_classes BEGIN
      INSERT INTO product_classes_fts(product_classes_fts, rowid, full_code, name_hr, name_en)
      VALUES ('delete', OLD.rowid, OLD.full_code, OLD.name_hr, OLD.name_en);
    END;
    """)

    # Trigger for UPDATE
    execute("""
    CREATE TRIGGER product_classes_fts_update AFTER UPDATE ON product_classes BEGIN
      INSERT INTO product_classes_fts(product_classes_fts, rowid, full_code, name_hr, name_en)
      VALUES ('delete', OLD.rowid, OLD.full_code, OLD.name_hr, OLD.name_en);
      INSERT INTO product_classes_fts(rowid, full_code, name_hr, name_en)
      VALUES (NEW.rowid, NEW.full_code, NEW.name_hr, NEW.name_en);
    END;
    """)
  end

  def down do
    # Drop FTS triggers
    execute("DROP TRIGGER IF EXISTS product_classes_fts_update;")
    execute("DROP TRIGGER IF EXISTS product_classes_fts_delete;")
    execute("DROP TRIGGER IF EXISTS product_classes_fts_insert;")

    # Drop FTS table
    execute("DROP TABLE IF EXISTS product_classes_fts;")

    # Drop main table (indexes are dropped automatically)
    execute("DROP TABLE IF EXISTS product_classes;")
  end
end
