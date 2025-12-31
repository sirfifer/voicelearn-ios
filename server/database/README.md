# UMCF Database Module

PostgreSQL storage backend for curricula with normalized tables and JSON export capability.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Storage Backends                          │
├─────────────────────────────────────────────────────────────┤
│  FileBasedStorage          │  PostgreSQLStorage             │
│  - Development             │  - Production                  │
│  - Simple deployments      │  - Full-text search            │
│  - No dependencies         │  - Concurrent access           │
│  - UMCF files on disk      │  - Normalized tables           │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Option 1: Docker (Recommended)

```bash
# Start PostgreSQL
cd server/database
docker-compose up -d

# Wait for database to be ready
sleep 5

# Run migration
python migrate.py --db-url postgresql://unamentis:unamentis_dev@localhost/unamentis --verify
```

### Option 2: Local PostgreSQL

```bash
# Create database
createdb unamentis

# Run schema
psql unamentis < schema.sql

# Run migration
python migrate.py --verify
```

## Configuration

Set environment variables to use PostgreSQL:

```bash
export UMCF_STORAGE_TYPE=postgresql
export UMCF_DATABASE_URL=postgresql://user:pass@host/unamentis
```

For development with Docker:
```bash
export UMCF_DATABASE_URL=postgresql://unamentis:unamentis_dev@localhost/unamentis
```

## Schema Overview

### Core Tables

- **curricula** - Top-level curriculum containers
- **topics** - Hierarchical content units
- **transcript_segments** - Individual speakable content
- **glossary_terms** - Vocabulary definitions

### Supporting Tables

- **curriculum_contributors** - Authors, editors
- **curriculum_alignments** - Standards alignment
- **learning_objectives** - Learning goals
- **examples** - Real-world examples
- **misconceptions** - Common misunderstandings
- **assessments** - Questions and quizzes

### Views

- **curriculum_summaries** - Fast listing with counts
- **topic_details** - Topic info with segment counts

### Functions

- **build_umcf_json(curriculum_id)** - Rebuild full UMCF JSON from normalized tables

## Migration

### From Files to PostgreSQL

```bash
# Preview what will be migrated
python migrate.py --dry-run

# Run migration
python migrate.py --verify

# Check results
psql unamentis -c "SELECT title, topic_count FROM curriculum_summaries"
```

### Rollback to Files

Simply change environment variables back to file-based storage:

```bash
unset UMCF_STORAGE_TYPE
unset UMCF_DATABASE_URL
```

## API

### Python Usage

```python
from database.curriculum_db import create_storage

# File-based (default)
storage = create_storage("file", curriculum_dir=Path("./curricula"))
await storage.reload()

# PostgreSQL
storage = create_storage("postgresql",
                         connection_string="postgresql://localhost/unamentis")
await storage.connect()

# List curricula
curricula, total = await storage.list_curricula(search="python")

# Get full UMCF JSON
umcf = await storage.get_curriculum_full("python-basics")
```

## Performance Notes

- File-based storage loads all curricula into memory at startup
- PostgreSQL storage uses connection pooling and lazy loading
- JSON cache in PostgreSQL is automatically rebuilt when content changes
- Full-text search uses PostgreSQL's built-in tsvector with GIN indexes
