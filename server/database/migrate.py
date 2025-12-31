#!/usr/bin/env python3
"""
UMCF Migration Script

Migrates existing UMCF curriculum files to PostgreSQL database.

Usage:
    python migrate.py                    # Uses environment variables
    python migrate.py --dry-run          # Preview without committing
    python migrate.py --db-url URL       # Explicit database URL

Environment Variables:
    UMCF_DATABASE_URL - PostgreSQL connection string
                       (default: postgresql://localhost/unamentis)

Steps to use:
1. Install PostgreSQL and create database:
   createdb unamentis

2. Run schema:
   psql unamentis < schema.sql

3. Run migration:
   python migrate.py

4. Set environment variable in server:
   export UMCF_STORAGE_TYPE=postgresql
   export UMCF_DATABASE_URL=postgresql://localhost/unamentis
"""

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    import asyncpg
except ImportError:
    print("Error: asyncpg is required for PostgreSQL migration")
    print("Install with: pip install asyncpg")
    sys.exit(1)


async def run_migration(
    db_url: str,
    curriculum_dir: Path,
    dry_run: bool = False
) -> int:
    """
    Migrate UMCF files to PostgreSQL.

    Returns:
        Number of curricula migrated
    """
    if not curriculum_dir.exists():
        print(f"Error: Curriculum directory not found: {curriculum_dir}")
        return 0

    # Find all UMCF files
    umcf_files = list(curriculum_dir.glob("*.umcf"))
    if not umcf_files:
        print(f"No UMCF files found in {curriculum_dir}")
        return 0

    print(f"Found {len(umcf_files)} UMCF files to migrate")

    if dry_run:
        print("\n[DRY RUN] Would migrate:")
        for f in umcf_files:
            print(f"  - {f.name}")
        return len(umcf_files)

    # Connect to database
    try:
        conn = await asyncpg.connect(db_url)
    except Exception as e:
        print(f"Error connecting to database: {e}")
        print(f"Connection string: {db_url}")
        return 0

    # Import storage module
    from database.curriculum_db import PostgreSQLStorage

    storage = PostgreSQLStorage(db_url)
    await storage.connect()

    migrated = 0
    errors = []

    for umcf_file in umcf_files:
        print(f"Migrating {umcf_file.name}...")
        try:
            with open(umcf_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            curriculum_id = data.get("id", {}).get("value", umcf_file.stem)
            await storage.save_curriculum(curriculum_id, data)
            migrated += 1
            print(f"  OK: {data.get('title', 'Untitled')}")

        except Exception as e:
            print(f"  ERROR: {e}")
            errors.append((umcf_file.name, str(e)))

    await storage.close()
    await conn.close()

    print(f"\nMigration complete: {migrated}/{len(umcf_files)} curricula migrated")

    if errors:
        print("\nErrors:")
        for name, error in errors:
            print(f"  - {name}: {error}")

    return migrated


async def verify_migration(db_url: str) -> bool:
    """Verify that migration was successful."""
    try:
        conn = await asyncpg.connect(db_url)

        count = await conn.fetchval("SELECT COUNT(*) FROM curricula")
        print(f"\nVerification: {count} curricula in database")

        # Check a sample curriculum
        sample = await conn.fetchrow("""
            SELECT title, topic_count
            FROM curriculum_summaries
            LIMIT 1
        """)
        if sample:
            print(f"Sample: '{sample['title']}' with {sample['topic_count']} topics")

        await conn.close()
        return count > 0

    except Exception as e:
        print(f"Verification failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Migrate UMCF files to PostgreSQL",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        "--db-url",
        help="PostgreSQL connection URL",
        default=os.environ.get("UMCF_DATABASE_URL", "postgresql://localhost/unamentis")
    )
    parser.add_argument(
        "--curriculum-dir",
        type=Path,
        help="Directory containing UMCF files",
        default=Path(__file__).parent.parent.parent / "curriculum" / "examples" / "realistic"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview migration without committing"
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify migration after completion"
    )

    args = parser.parse_args()

    print("UMCF to PostgreSQL Migration")
    print("=" * 50)
    print(f"Database URL: {args.db_url}")
    print(f"Curriculum Directory: {args.curriculum_dir}")
    print()

    count = asyncio.run(run_migration(
        args.db_url,
        args.curriculum_dir,
        args.dry_run
    ))

    if count > 0 and args.verify and not args.dry_run:
        asyncio.run(verify_migration(args.db_url))

    return 0 if count > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
