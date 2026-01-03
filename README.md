# KPD as a Service

KPD (Klasifikacija Proizvoda po Djelatnostima) as a Service - An Elixir service for querying hierarchical Croatian product classification data.

**Distributable as a single executable** via [Burrito](https://github.com/burrito-elixir/burrito) - no Erlang/Elixir installation required!

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
- **HTTP REST API** powered by Bandit and Plug
- **Hierarchical queries**: get children, descendants, parent, ancestors
- **Bilingual search**: search in Croatian, English, or both languages
- **CSV import**: batch import from official DZS (Croatian Bureau of Statistics) CSV files
- **Validity filtering**: optionally exclude expired entries
- **OpenAPI 3.0 specification** for API documentation

## Installation

1. Install dependencies:

```bash
mix deps.get
```

2. Create and migrate the database:

```bash
mix ecto.setup
```

## HTTP API

The service exposes a REST API on port 4000 (configurable). The API is documented using OpenAPI 3.0 specification available at `/api/openapi.yaml`.

### Starting the Server

The HTTP server is enabled by default in dev mode. To start it:

```bash
iex -S mix
```

The server will be available at `http://localhost:4000`.

### API Endpoints

#### Health & Statistics

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/stats` | Database statistics |
| GET | `/api/openapi.yaml` | OpenAPI specification |

#### Product Classes

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/product_classes` | List product classes (paginated) |
| GET | `/api/product_classes/roots` | List root categories (level 1) |
| GET | `/api/product_classes/by_code/{code}` | Get product class by code |

#### Search

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/product_classes/search?q={query}` | Fuzzy search by name |
| GET | `/api/product_classes/search_by_code?code={prefix}` | Search by code prefix |

#### Hierarchy Navigation

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/product_classes/by_code/{code}/children` | Get direct children |
| GET | `/api/product_classes/by_code/{code}/descendants` | Get all descendants |
| GET | `/api/product_classes/by_code/{code}/parent` | Get parent |
| GET | `/api/product_classes/by_code/{code}/ancestors` | Get all ancestors |
| GET | `/api/product_classes/by_code/{code}/full_path` | Get full path from root |

### Query Parameters

Common query parameters:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `level` | integer (1-6) | Filter by hierarchy level | - |
| `limit` | integer | Maximum results | 100 (list), 20 (search) |
| `offset` | integer | Pagination offset | 0 |
| `include_expired` | boolean | Include expired entries | false |
| `lang` | string (hr/en/all) | Search language | all |

### Example Requests

```bash
# List all root categories
curl http://localhost:4000/api/product_classes/roots

# Search for "agriculture" in English
curl "http://localhost:4000/api/product_classes/search?q=agriculture&lang=en"

# Get product class by code
curl http://localhost:4000/api/product_classes/by_code/A01.11

# Get children of a product class
curl http://localhost:4000/api/product_classes/by_code/A/children

# Get statistics
curl http://localhost:4000/api/stats
```

### Response Format

All responses are JSON. List responses include a `data` array and `count`:

```json
{
  "data": [
    {
      "code": "A",
      "name_hr": "Poljoprivreda, šumarstvo i ribarstvo",
      "name_en": "Agriculture, forestry and fishing",
      "level": 1,
      "start_date": "2025-01-01",
      "end_date": null
    }
  ],
  "count": 1
}
```

Single item responses wrap the item in `data`:

```json
{
  "data": {
    "code": "A",
    "name_hr": "...",
    ...
  }
}
```

Error responses include an `error` field:

```json
{
  "error": "Product class not found"
}
```

## Configuration

### HTTP Server

Configure the HTTP server in your environment config:

```elixir
# config/dev.exs
config :kpd,
  server: true,
  port: 4000,
  enable_exsync: true
```

### Auto-Reload

In development mode, the server automatically reloads code when files change (powered by ExSync). This is enabled by default in dev configuration.

To disable auto-reload:

```elixir
config :kpd,
  enable_exsync: false
```

## Importing Data

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

## Elixir API Functions

### Listing

```elixir
# List all product classes (paginated)
KPD.list(limit: 100, offset: 0)

# List only root categories (level 1)
KPD.list_roots()

# List by specific level
KPD.list(level: 3)

# Include expired entries
KPD.list(include_expired: true)
```

### Getting Single Entries

```elixir
# Get by code
KPD.get_by_code("A01.11")

# Get by ID
KPD.get(123)
```

### Hierarchical Queries

```elixir
# Get direct children
KPD.get_children("A.01")

# Get all descendants (all levels below)
KPD.get_descendants("A.01")

# Get parent
KPD.get_parent("A.01.1")

# Get all ancestors (from root to immediate parent)
KPD.get_ancestors("A.01.1.1.1.1")

# Get full path (ancestors + self)
KPD.get_full_path("A.01.1.1.1.1")
```

### Searching

```elixir
# Search in both Croatian and English names
KPD.search("poljoprivreda")

# Search only Croatian names
KPD.search("pšenica", lang: :hr)

# Search only English names
KPD.search("agriculture", lang: :en)

# Search with filters
KPD.search("wheat", lang: :en, level: 6, limit: 10)

# Search by code prefix
KPD.search_by_code("A01")
```

### Counting

```elixir
# Total count
KPD.count()

# Count by level
KPD.count(level: 1)
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

## Building Standalone Executables with Burrito

The project is configured to build self-contained executables using Burrito. The executable includes:
- The compiled Elixir application
- The Erlang runtime (ERTS)
- A pre-populated SQLite database with all KPD classification data

### Prerequisites

Install the required build tools:

```bash
# macOS
brew install zig xz

# Ubuntu/Debian
sudo apt install zig xz-utils

# Or download Zig directly from https://ziglang.org/download/
```

For Windows targets, you also need 7-Zip (`7z`).

### Building the Release

Build for all configured targets:

```bash
MIX_ENV=prod mix release
```

Build for a specific target:

```bash
# macOS Apple Silicon
MIX_ENV=prod BURRITO_TARGET=macos_apple_silicon mix release

# macOS Intel
MIX_ENV=prod BURRITO_TARGET=macos_intel mix release

# Linux AMD64
MIX_ENV=prod BURRITO_TARGET=linux_amd64 mix release

# Linux ARM64
MIX_ENV=prod BURRITO_TARGET=linux_arm64 mix release
```

The built executables will be in the `burrito_out/` directory.

### Running the Executable

Run the server with default settings (port 4000, bind to 0.0.0.0):

```bash
./kpd_server
```

### Environment Variables

Configure the server at runtime using environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP port to listen on | `4000` |
| `IP` | IP address to bind to | `0.0.0.0` |
| `SERVER` | Start HTTP server (`true`/`false`) | `true` |

Examples:

```bash
# Run on a different port
PORT=8080 ./kpd_server

# Bind to localhost only
IP=127.0.0.1 ./kpd_server

# Custom port and IP
IP=127.0.0.1 PORT=3000 ./kpd_server

# Don't start the HTTP server (useful for debugging)
SERVER=false ./kpd_server
```

### Build Targets

The following targets are pre-configured:

| Target | OS | Architecture |
|--------|-----|--------------|
| `macos_intel` | macOS | x86_64 |
| `macos_apple_silicon` | macOS | ARM64 (M1/M2/M3) |
| `linux_amd64` | Linux | x86_64 |
| `linux_arm64` | Linux | ARM64 |

### How It Works

During the build process:
1. The Mix release is assembled
2. A custom build step (`KPD.Release.ImportDataStep`) runs in the patch phase
3. This step creates a fresh SQLite database, runs migrations, and imports all KPD data from `priv/data/kpd-2025.csv.gz`
4. The FTS (Full-Text Search) index is rebuilt
5. Burrito packages everything into a self-extracting executable

At runtime:
1. The executable extracts its payload to a cache directory (first run only)
2. The bundled Erlang runtime starts your application
3. The pre-populated database is ready to use immediately

### Maintenance Commands

Burrito includes built-in maintenance commands:

```bash
# Show installation directory
./kpd_server maintenance directory

# Uninstall extracted payload
./kpd_server maintenance uninstall

# Show binary metadata
./kpd_server maintenance meta
```

## License

MIT
