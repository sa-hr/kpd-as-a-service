# KPD as a Service

KPD (Klasifikacija Proizvoda po Djelatnostima) as a Service - An Elixir service for querying hierarchical Croatian product classification data.

## Overview

This service provides a way to list and search through hierarchical KPD product classification data with 6 levels of nesting. Each product class has:

- Croatian name (`name_hr`)
- English name (`name_en`)
- Unique code
- Hierarchical path for tree traversal
- Validity dates (start_date, end_date)

The classification hierarchy follows this structure:

| Level | Name (EN)    | Example Code |
|-------|--------------|--------------|
| 1     | Section      | A            |
| 2     | Division     | A01          |
| 3     | Group        | A01.1        |
| 4     | Class        | A01.11       |
| 5     | Category     | A01.11.1     |
| 6     | Subcategory  | A01.11.11    |

## Features

- **SQLite database** with FTS5 trigram search for fuzzy name matching
- **Hierarchical queries**: get children, descendants, parent, ancestors
- **Bilingual search**: search in Croatian, English, or both languages
- **CSV import**: batch import from official DZS (Croatian Bureau of Statistics) CSV files
- **Validity filtering**: optionally exclude expired entries

## Installation

1. Install dependencies:

```bash
mix deps.get
```

2. Create and migrate the database:

```bash
mix ecto.setup
```

## Usage

### Importing Data

Import KPD data from a CSV file:

```bash
# Import from CSV
mix kpd.import path/to/kpd_data.csv

# Import from gzipped CSV
mix kpd.import path/to/kpd_data.csv.gz

# With custom batch size
mix kpd.import path/to/kpd_data.csv --batch-size 1000

# Rebuild FTS index after import
mix kpd.import path/to/kpd_data.csv --rebuild-fts
```

The CSV should have the following columns (from DZS Klasus export):
- Službena šifra
- Datum početka
- Datum završetka
- Službeni naziv HR
- Kratki naziv HR
- Službeni naziv EN
- Kratki naziv EN
- Broj razine
- Potpuna šifra

Data source: https://web.dzs.hr/app/klasus/

### API Functions

#### Listing

```elixir
# List all product classes (paginated)
KpdAsAService.list(limit: 100, offset: 0)

# List only root categories (level 1)
KpdAsAService.list_roots()

# List by specific level
KpdAsAService.list(level: 3)

# Include expired entries
KpdAsAService.list(include_expired: true)
```

#### Getting Single Entries

```elixir
# Get by code
KpdAsAService.get_by_code("A01.11")

# Get by ID
KpdAsAService.get(123)
```

#### Hierarchical Queries

```elixir
# Get direct children
KpdAsAService.get_children("A.01")

# Get all descendants (all levels below)
KpdAsAService.get_descendants("A.01")

# Get parent
KpdAsAService.get_parent("A.01.1")

# Get all ancestors (from root to immediate parent)
KpdAsAService.get_ancestors("A.01.1.1.1.1")

# Get full path (ancestors + self)
KpdAsAService.get_full_path("A.01.1.1.1.1")
```

#### Searching

```elixir
# Search in both Croatian and English names
KpdAsAService.search("poljoprivreda")

# Search only Croatian names
KpdAsAService.search("pšenica", lang: :hr)

# Search only English names
KpdAsAService.search("agriculture", lang: :en)

# Search with filters
KpdAsAService.search("wheat", lang: :en, level: 6, limit: 10)

# Search by code prefix
KpdAsAService.search_by_code("A01")
```

#### Counting

```elixir
# Total count
KpdAsAService.count()

# Count by level
KpdAsAService.count(level: 1)
```

## Architecture

### Database Schema

The main table `product_classes` stores all KPD entries:

| Column      | Type     | Description                    |
|-------------|----------|--------------------------------|
| id          | integer  | Primary key                    |
| code        | string   | Official KPD code (unique)     |
| path        | string   | Dot-separated path for hierarchy |
| name_hr     | string   | Croatian name                  |
| name_en     | string   | English name                   |
| start_date  | date     | Validity start date            |
| end_date    | date     | Validity end date (nullable)   |
| level       | integer  | Hierarchy level (1-6)          |

### FTS5 Trigram Search

A virtual table `product_classes_fts` provides full-text search with trigram tokenization:

- Enables fuzzy matching for misspellings
- Indexes code, name_hr, and name_en
- Automatically kept in sync via triggers

## Development

Run tests:

```bash
mix test
```

Start an interactive session:

```bash
iex -S mix
```

Reset the database:

```bash
mix ecto.reset
```

## License

MIT