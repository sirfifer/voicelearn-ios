# TTS Pre-Generation Repository
# PostgreSQL queries for TTS profiles, jobs, and comparison sessions

import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple
from uuid import UUID

import asyncpg

from .models import (
    TTSProfile,
    TTSProfileSettings,
    TTSModuleProfile,
    TTSPregenJob,
    TTSJobItem,
    TTSComparisonSession,
    TTSComparisonVariant,
    TTSComparisonRating,
    JobStatus,
    ItemStatus,
    SessionStatus,
    VariantStatus,
)

logger = logging.getLogger(__name__)


class TTSPregenRepository:
    """Repository for TTS pre-generation database operations.

    Uses asyncpg connection pool for PostgreSQL access.
    All methods expect the pool to be passed in or set on initialization.
    """

    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    # =========================================================================
    # PROFILE OPERATIONS
    # =========================================================================

    async def create_profile(self, profile: TTSProfile) -> TTSProfile:
        """Create a new TTS profile."""
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO tts_profiles (
                    id, name, description, provider, voice_id, settings,
                    tags, use_case, is_active, is_default,
                    created_at, updated_at, created_from_session_id,
                    sample_audio_path, sample_text
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
                """,
                profile.id,
                profile.name,
                profile.description,
                profile.provider,
                profile.voice_id,
                json.dumps(profile.settings.to_dict()),
                profile.tags,
                profile.use_case,
                profile.is_active,
                profile.is_default,
                profile.created_at,
                profile.updated_at,
                profile.created_from_session_id,
                profile.sample_audio_path,
                profile.sample_text,
            )
            logger.info(f"Created TTS profile: {profile.name} ({profile.id})")
            return profile

    async def get_profile(self, profile_id: UUID) -> Optional[TTSProfile]:
        """Get a profile by ID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tts_profiles WHERE id = $1",
                profile_id,
            )
            if row:
                return self._row_to_profile(row)
            return None

    async def get_profile_by_name(self, name: str) -> Optional[TTSProfile]:
        """Get a profile by name."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tts_profiles WHERE name = $1",
                name,
            )
            if row:
                return self._row_to_profile(row)
            return None

    async def list_profiles(
        self,
        provider: Optional[str] = None,
        tags: Optional[List[str]] = None,
        use_case: Optional[str] = None,
        is_active: Optional[bool] = True,
        limit: int = 100,
        offset: int = 0,
    ) -> Tuple[List[TTSProfile], int]:
        """List profiles with optional filtering."""
        async with self.pool.acquire() as conn:
            # Build query conditions
            conditions = []
            params: List[Any] = []
            param_idx = 1

            if provider:
                conditions.append(f"provider = ${param_idx}")
                params.append(provider)
                param_idx += 1

            if tags:
                conditions.append(f"tags && ${param_idx}")
                params.append(tags)
                param_idx += 1

            if use_case:
                conditions.append(f"use_case = ${param_idx}")
                params.append(use_case)
                param_idx += 1

            if is_active is not None:
                conditions.append(f"is_active = ${param_idx}")
                params.append(is_active)
                param_idx += 1

            where_clause = " AND ".join(conditions) if conditions else "TRUE"

            # Get total count
            count_query = f"SELECT COUNT(*) FROM tts_profiles WHERE {where_clause}"
            total = await conn.fetchval(count_query, *params)

            # Get profiles
            query = f"""
                SELECT * FROM tts_profiles
                WHERE {where_clause}
                ORDER BY is_default DESC, name ASC
                LIMIT ${param_idx} OFFSET ${param_idx + 1}
            """
            params.extend([limit, offset])

            rows = await conn.fetch(query, *params)
            profiles = [self._row_to_profile(row) for row in rows]

            return profiles, total

    async def update_profile(self, profile: TTSProfile) -> TTSProfile:
        """Update an existing profile."""
        profile.updated_at = datetime.now()
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE tts_profiles SET
                    name = $2, description = $3, provider = $4, voice_id = $5,
                    settings = $6, tags = $7, use_case = $8, is_active = $9,
                    is_default = $10, updated_at = $11, sample_audio_path = $12,
                    sample_text = $13
                WHERE id = $1
                """,
                profile.id,
                profile.name,
                profile.description,
                profile.provider,
                profile.voice_id,
                json.dumps(profile.settings.to_dict()),
                profile.tags,
                profile.use_case,
                profile.is_active,
                profile.is_default,
                profile.updated_at,
                profile.sample_audio_path,
                profile.sample_text,
            )
            logger.info(f"Updated TTS profile: {profile.name} ({profile.id})")
            return profile

    async def delete_profile(self, profile_id: UUID, soft: bool = True) -> bool:
        """Delete a profile (soft delete by default)."""
        async with self.pool.acquire() as conn:
            if soft:
                result = await conn.execute(
                    "UPDATE tts_profiles SET is_active = FALSE, updated_at = $2 WHERE id = $1",
                    profile_id,
                    datetime.now(),
                )
            else:
                result = await conn.execute(
                    "DELETE FROM tts_profiles WHERE id = $1",
                    profile_id,
                )
            deleted = result.split()[-1] != "0"
            if deleted:
                logger.info(f"Deleted TTS profile: {profile_id} (soft={soft})")
            return deleted

    async def set_default_profile(self, profile_id: UUID) -> None:
        """Set a profile as the default (only one can be default)."""
        async with self.pool.acquire() as conn:
            # Clear existing default
            await conn.execute("UPDATE tts_profiles SET is_default = FALSE WHERE is_default = TRUE")
            # Set new default
            await conn.execute(
                "UPDATE tts_profiles SET is_default = TRUE, updated_at = $2 WHERE id = $1",
                profile_id,
                datetime.now(),
            )
            logger.info(f"Set default TTS profile: {profile_id}")

    def _row_to_profile(self, row: asyncpg.Record) -> TTSProfile:
        """Convert database row to TTSProfile."""
        settings_dict = row["settings"] if isinstance(row["settings"], dict) else json.loads(row["settings"])
        return TTSProfile(
            id=row["id"],
            name=row["name"],
            description=row["description"],
            provider=row["provider"],
            voice_id=row["voice_id"],
            settings=TTSProfileSettings.from_dict(settings_dict),
            tags=row["tags"] or [],
            use_case=row["use_case"],
            is_active=row["is_active"],
            is_default=row["is_default"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            created_from_session_id=row["created_from_session_id"],
            sample_audio_path=row["sample_audio_path"],
            sample_text=row["sample_text"],
        )

    # =========================================================================
    # MODULE PROFILE ASSOCIATIONS
    # =========================================================================

    async def assign_profile_to_module(
        self,
        module_id: str,
        profile_id: UUID,
        context: Optional[str] = None,
        priority: int = 0,
    ) -> TTSModuleProfile:
        """Assign a profile to a module."""
        from uuid import uuid4

        assoc = TTSModuleProfile(
            id=uuid4(),
            module_id=module_id,
            profile_id=profile_id,
            context=context,
            priority=priority,
        )

        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO tts_module_profiles (id, module_id, profile_id, context, priority, created_at)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (module_id, profile_id, context) DO UPDATE SET
                    priority = EXCLUDED.priority
                """,
                assoc.id,
                assoc.module_id,
                assoc.profile_id,
                assoc.context,
                assoc.priority,
                assoc.created_at,
            )
            logger.info(f"Assigned profile {profile_id} to module {module_id}")
            return assoc

    async def get_module_profiles(self, module_id: str) -> List[Tuple[TTSModuleProfile, TTSProfile]]:
        """Get all profiles for a module with their associations."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT mp.*, p.*
                FROM tts_module_profiles mp
                JOIN tts_profiles p ON mp.profile_id = p.id
                WHERE mp.module_id = $1 AND p.is_active = TRUE
                ORDER BY mp.priority DESC, p.name ASC
                """,
                module_id,
            )
            results = []
            for row in rows:
                assoc = TTSModuleProfile(
                    id=row["id"],
                    module_id=row["module_id"],
                    profile_id=row["profile_id"],
                    context=row["context"],
                    priority=row["priority"],
                    created_at=row["created_at"],
                )
                profile = self._row_to_profile(row)
                results.append((assoc, profile))
            return results

    async def remove_profile_from_module(self, module_id: str, profile_id: UUID) -> bool:
        """Remove a profile assignment from a module."""
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                "DELETE FROM tts_module_profiles WHERE module_id = $1 AND profile_id = $2",
                module_id,
                profile_id,
            )
            deleted = result.split()[-1] != "0"
            if deleted:
                logger.info(f"Removed profile {profile_id} from module {module_id}")
            return deleted

    # =========================================================================
    # JOB OPERATIONS
    # =========================================================================

    async def create_job(self, job: TTSPregenJob) -> TTSPregenJob:
        """Create a new pre-generation job."""
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO tts_pregen_jobs (
                    id, name, job_type, status, source_type, source_id,
                    profile_id, tts_config, output_format, normalize_volume, output_dir,
                    total_items, completed_items, failed_items,
                    current_item_index, current_item_text,
                    created_at, started_at, paused_at, completed_at, updated_at,
                    last_error, consecutive_failures
                ) VALUES (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
                    $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23
                )
                """,
                job.id,
                job.name,
                job.job_type,
                job.status.value,
                job.source_type,
                job.source_id,
                job.profile_id,
                json.dumps(job.tts_config) if job.tts_config else None,
                job.output_format,
                job.normalize_volume,
                job.output_dir,
                job.total_items,
                job.completed_items,
                job.failed_items,
                job.current_item_index,
                job.current_item_text,
                job.created_at,
                job.started_at,
                job.paused_at,
                job.completed_at,
                job.updated_at,
                job.last_error,
                job.consecutive_failures,
            )
            logger.info(f"Created TTS job: {job.name} ({job.id})")
            return job

    async def get_job(self, job_id: UUID) -> Optional[TTSPregenJob]:
        """Get a job by ID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tts_pregen_jobs WHERE id = $1",
                job_id,
            )
            if row:
                return self._row_to_job(row)
            return None

    async def list_jobs(
        self,
        status: Optional[JobStatus] = None,
        source_type: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> Tuple[List[TTSPregenJob], int]:
        """List jobs with optional filtering."""
        async with self.pool.acquire() as conn:
            conditions = []
            params: List[Any] = []
            param_idx = 1

            if status:
                conditions.append(f"status = ${param_idx}")
                params.append(status.value)
                param_idx += 1

            if source_type:
                conditions.append(f"source_type = ${param_idx}")
                params.append(source_type)
                param_idx += 1

            where_clause = " AND ".join(conditions) if conditions else "TRUE"

            total = await conn.fetchval(
                f"SELECT COUNT(*) FROM tts_pregen_jobs WHERE {where_clause}",
                *params,
            )

            query = f"""
                SELECT * FROM tts_pregen_jobs
                WHERE {where_clause}
                ORDER BY created_at DESC
                LIMIT ${param_idx} OFFSET ${param_idx + 1}
            """
            params.extend([limit, offset])

            rows = await conn.fetch(query, *params)
            jobs = [self._row_to_job(row) for row in rows]

            return jobs, total

    async def update_job(self, job: TTSPregenJob) -> TTSPregenJob:
        """Update a job."""
        job.updated_at = datetime.now()
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE tts_pregen_jobs SET
                    status = $2, total_items = $3, completed_items = $4,
                    failed_items = $5, current_item_index = $6, current_item_text = $7,
                    started_at = $8, paused_at = $9, completed_at = $10, updated_at = $11,
                    last_error = $12, consecutive_failures = $13
                WHERE id = $1
                """,
                job.id,
                job.status.value,
                job.total_items,
                job.completed_items,
                job.failed_items,
                job.current_item_index,
                job.current_item_text,
                job.started_at,
                job.paused_at,
                job.completed_at,
                job.updated_at,
                job.last_error,
                job.consecutive_failures,
            )
            return job

    async def update_job_status(
        self,
        job_id: UUID,
        status: JobStatus,
        error: Optional[str] = None,
    ) -> None:
        """Update just the job status."""
        async with self.pool.acquire() as conn:
            if status == JobStatus.RUNNING:
                await conn.execute(
                    """
                    UPDATE tts_pregen_jobs SET
                        status = $2, started_at = COALESCE(started_at, $3),
                        updated_at = $3, last_error = $4
                    WHERE id = $1
                    """,
                    job_id,
                    status.value,
                    datetime.now(),
                    error,
                )
            elif status == JobStatus.PAUSED:
                await conn.execute(
                    """
                    UPDATE tts_pregen_jobs SET
                        status = $2, paused_at = $3, updated_at = $3, last_error = $4
                    WHERE id = $1
                    """,
                    job_id,
                    status.value,
                    datetime.now(),
                    error,
                )
            elif status in (JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED):
                await conn.execute(
                    """
                    UPDATE tts_pregen_jobs SET
                        status = $2, completed_at = $3, updated_at = $3, last_error = $4
                    WHERE id = $1
                    """,
                    job_id,
                    status.value,
                    datetime.now(),
                    error,
                )
            else:
                await conn.execute(
                    "UPDATE tts_pregen_jobs SET status = $2, updated_at = $3, last_error = $4 WHERE id = $1",
                    job_id,
                    status.value,
                    datetime.now(),
                    error,
                )

    def _row_to_job(self, row: asyncpg.Record) -> TTSPregenJob:
        """Convert database row to TTSPregenJob."""
        tts_config = row["tts_config"]
        if tts_config and isinstance(tts_config, str):
            tts_config = json.loads(tts_config)

        return TTSPregenJob(
            id=row["id"],
            name=row["name"],
            job_type=row["job_type"],
            status=JobStatus(row["status"]),
            source_type=row["source_type"],
            source_id=row["source_id"],
            profile_id=row["profile_id"],
            tts_config=tts_config,
            output_format=row["output_format"],
            normalize_volume=row["normalize_volume"],
            output_dir=row["output_dir"],
            total_items=row["total_items"],
            completed_items=row["completed_items"],
            failed_items=row["failed_items"],
            current_item_index=row["current_item_index"],
            current_item_text=row["current_item_text"],
            created_at=row["created_at"],
            started_at=row["started_at"],
            paused_at=row["paused_at"],
            completed_at=row["completed_at"],
            updated_at=row["updated_at"],
            last_error=row["last_error"],
            consecutive_failures=row["consecutive_failures"],
        )

    # =========================================================================
    # JOB ITEM OPERATIONS
    # =========================================================================

    async def create_job_items(self, items: List[TTSJobItem]) -> int:
        """Bulk create job items."""
        if not items:
            return 0

        async with self.pool.acquire() as conn:
            # Use COPY for bulk insert
            await conn.executemany(
                """
                INSERT INTO tts_pregen_job_items (
                    id, job_id, item_index, text_content, text_hash, source_ref,
                    status, attempt_count, output_file, duration_seconds,
                    file_size_bytes, sample_rate, last_error,
                    processing_started_at, processing_completed_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
                """,
                [
                    (
                        item.id,
                        item.job_id,
                        item.item_index,
                        item.text_content,
                        item.text_hash,
                        item.source_ref,
                        item.status.value,
                        item.attempt_count,
                        item.output_file,
                        item.duration_seconds,
                        item.file_size_bytes,
                        item.sample_rate,
                        item.last_error,
                        item.processing_started_at,
                        item.processing_completed_at,
                    )
                    for item in items
                ],
            )
            logger.info(f"Created {len(items)} job items for job {items[0].job_id}")
            return len(items)

    async def get_job_items(
        self,
        job_id: UUID,
        status: Optional[ItemStatus] = None,
        limit: int = 1000,
        offset: int = 0,
    ) -> List[TTSJobItem]:
        """Get items for a job."""
        async with self.pool.acquire() as conn:
            if status:
                rows = await conn.fetch(
                    """
                    SELECT * FROM tts_pregen_job_items
                    WHERE job_id = $1 AND status = $2
                    ORDER BY item_index
                    LIMIT $3 OFFSET $4
                    """,
                    job_id,
                    status.value,
                    limit,
                    offset,
                )
            else:
                rows = await conn.fetch(
                    """
                    SELECT * FROM tts_pregen_job_items
                    WHERE job_id = $1
                    ORDER BY item_index
                    LIMIT $2 OFFSET $3
                    """,
                    job_id,
                    limit,
                    offset,
                )
            return [self._row_to_item(row) for row in rows]

    async def get_pending_items(self, job_id: UUID, limit: int = 100) -> List[TTSJobItem]:
        """Get pending items for processing."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT * FROM tts_pregen_job_items
                WHERE job_id = $1 AND status = 'pending'
                ORDER BY item_index
                LIMIT $2
                """,
                job_id,
                limit,
            )
            return [self._row_to_item(row) for row in rows]

    async def update_item_status(
        self,
        item_id: UUID,
        status: ItemStatus,
        output_file: Optional[str] = None,
        duration_seconds: Optional[float] = None,
        file_size_bytes: Optional[int] = None,
        sample_rate: Optional[int] = None,
        error: Optional[str] = None,
    ) -> None:
        """Update a job item's status and result."""
        async with self.pool.acquire() as conn:
            now = datetime.now()
            if status == ItemStatus.PROCESSING:
                await conn.execute(
                    """
                    UPDATE tts_pregen_job_items SET
                        status = $2, processing_started_at = $3,
                        attempt_count = attempt_count + 1
                    WHERE id = $1
                    """,
                    item_id,
                    status.value,
                    now,
                )
            elif status == ItemStatus.COMPLETED:
                await conn.execute(
                    """
                    UPDATE tts_pregen_job_items SET
                        status = $2, output_file = $3, duration_seconds = $4,
                        file_size_bytes = $5, sample_rate = $6,
                        processing_completed_at = $7
                    WHERE id = $1
                    """,
                    item_id,
                    status.value,
                    output_file,
                    duration_seconds,
                    file_size_bytes,
                    sample_rate,
                    now,
                )
            elif status == ItemStatus.FAILED:
                await conn.execute(
                    """
                    UPDATE tts_pregen_job_items SET
                        status = $2, last_error = $3, processing_completed_at = $4
                    WHERE id = $1
                    """,
                    item_id,
                    status.value,
                    error,
                    now,
                )
            else:
                await conn.execute(
                    "UPDATE tts_pregen_job_items SET status = $2 WHERE id = $1",
                    item_id,
                    status.value,
                )

    async def reset_failed_items(self, job_id: UUID) -> int:
        """Reset failed items to pending for retry."""
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                """
                UPDATE tts_pregen_job_items SET
                    status = 'pending', last_error = NULL
                WHERE job_id = $1 AND status = 'failed'
                """,
                job_id,
            )
            count = int(result.split()[-1])
            logger.info(f"Reset {count} failed items for job {job_id}")
            return count

    def _row_to_item(self, row: asyncpg.Record) -> TTSJobItem:
        """Convert database row to TTSJobItem."""
        return TTSJobItem(
            id=row["id"],
            job_id=row["job_id"],
            item_index=row["item_index"],
            text_content=row["text_content"],
            text_hash=row["text_hash"],
            source_ref=row["source_ref"],
            status=ItemStatus(row["status"]),
            attempt_count=row["attempt_count"],
            output_file=row["output_file"],
            duration_seconds=row["duration_seconds"],
            file_size_bytes=row["file_size_bytes"],
            sample_rate=row["sample_rate"],
            last_error=row["last_error"],
            processing_started_at=row["processing_started_at"],
            processing_completed_at=row["processing_completed_at"],
        )

    # =========================================================================
    # COMPARISON SESSION OPERATIONS
    # =========================================================================

    async def create_session(self, session: TTSComparisonSession) -> TTSComparisonSession:
        """Create a new comparison session."""
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO tts_comparison_sessions (
                    id, name, description, status, config, created_at, updated_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7)
                """,
                session.id,
                session.name,
                session.description,
                session.status.value,
                json.dumps(session.config),
                session.created_at,
                session.updated_at,
            )
            logger.info(f"Created comparison session: {session.name} ({session.id})")
            return session

    async def get_session(self, session_id: UUID) -> Optional[TTSComparisonSession]:
        """Get a comparison session by ID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tts_comparison_sessions WHERE id = $1",
                session_id,
            )
            if row:
                return self._row_to_session(row)
            return None

    async def list_sessions(
        self,
        status: Optional[SessionStatus] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> Tuple[List[TTSComparisonSession], int]:
        """List comparison sessions."""
        async with self.pool.acquire() as conn:
            if status:
                total = await conn.fetchval(
                    "SELECT COUNT(*) FROM tts_comparison_sessions WHERE status = $1",
                    status.value,
                )
                rows = await conn.fetch(
                    """
                    SELECT * FROM tts_comparison_sessions
                    WHERE status = $1
                    ORDER BY created_at DESC
                    LIMIT $2 OFFSET $3
                    """,
                    status.value,
                    limit,
                    offset,
                )
            else:
                total = await conn.fetchval("SELECT COUNT(*) FROM tts_comparison_sessions")
                rows = await conn.fetch(
                    """
                    SELECT * FROM tts_comparison_sessions
                    ORDER BY created_at DESC
                    LIMIT $1 OFFSET $2
                    """,
                    limit,
                    offset,
                )

            sessions = [self._row_to_session(row) for row in rows]
            return sessions, total

    async def update_session_status(self, session_id: UUID, status: SessionStatus) -> None:
        """Update session status."""
        async with self.pool.acquire() as conn:
            await conn.execute(
                "UPDATE tts_comparison_sessions SET status = $2, updated_at = $3 WHERE id = $1",
                session_id,
                status.value,
                datetime.now(),
            )

    async def delete_session(self, session_id: UUID) -> bool:
        """Delete a comparison session."""
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                "DELETE FROM tts_comparison_sessions WHERE id = $1",
                session_id,
            )
            deleted = result.split()[-1] != "0"
            if deleted:
                logger.info(f"Deleted comparison session: {session_id}")
            return deleted

    def _row_to_session(self, row: asyncpg.Record) -> TTSComparisonSession:
        """Convert database row to TTSComparisonSession."""
        config = row["config"]
        if isinstance(config, str):
            config = json.loads(config)

        return TTSComparisonSession(
            id=row["id"],
            name=row["name"],
            description=row["description"],
            status=SessionStatus(row["status"]),
            config=config,
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )

    # =========================================================================
    # COMPARISON VARIANT OPERATIONS
    # =========================================================================

    async def create_variants(self, variants: List[TTSComparisonVariant]) -> int:
        """Bulk create comparison variants."""
        if not variants:
            return 0

        async with self.pool.acquire() as conn:
            await conn.executemany(
                """
                INSERT INTO tts_comparison_variants (
                    id, session_id, sample_index, config_index,
                    text_content, tts_config, status,
                    output_file, duration_seconds, last_error
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                """,
                [
                    (
                        v.id,
                        v.session_id,
                        v.sample_index,
                        v.config_index,
                        v.text_content,
                        json.dumps(v.tts_config),
                        v.status.value,
                        v.output_file,
                        v.duration_seconds,
                        v.last_error,
                    )
                    for v in variants
                ],
            )
            return len(variants)

    async def get_session_variants(self, session_id: UUID) -> List[TTSComparisonVariant]:
        """Get all variants for a session."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT * FROM tts_comparison_variants
                WHERE session_id = $1
                ORDER BY sample_index, config_index
                """,
                session_id,
            )
            return [self._row_to_variant(row) for row in rows]

    async def get_variant(self, variant_id: UUID) -> Optional[TTSComparisonVariant]:
        """Get a variant by ID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tts_comparison_variants WHERE id = $1",
                variant_id,
            )
            if row:
                return self._row_to_variant(row)
            return None

    async def update_variant_status(
        self,
        variant_id: UUID,
        status: VariantStatus,
        output_file: Optional[str] = None,
        duration_seconds: Optional[float] = None,
        error: Optional[str] = None,
    ) -> None:
        """Update variant status."""
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE tts_comparison_variants SET
                    status = $2, output_file = $3, duration_seconds = $4, last_error = $5
                WHERE id = $1
                """,
                variant_id,
                status.value,
                output_file,
                duration_seconds,
                error,
            )

    def _row_to_variant(self, row: asyncpg.Record) -> TTSComparisonVariant:
        """Convert database row to TTSComparisonVariant."""
        tts_config = row["tts_config"]
        if isinstance(tts_config, str):
            tts_config = json.loads(tts_config)

        return TTSComparisonVariant(
            id=row["id"],
            session_id=row["session_id"],
            sample_index=row["sample_index"],
            config_index=row["config_index"],
            text_content=row["text_content"],
            tts_config=tts_config,
            status=VariantStatus(row["status"]),
            output_file=row["output_file"],
            duration_seconds=row["duration_seconds"],
            last_error=row["last_error"],
        )

    # =========================================================================
    # RATING OPERATIONS
    # =========================================================================

    async def create_or_update_rating(self, rating: TTSComparisonRating) -> TTSComparisonRating:
        """Create or update a rating for a variant.

        Uses UPSERT to atomically insert or update, avoiding TOCTOU race conditions.
        """
        async with self.pool.acquire() as conn:
            # Use UPSERT to atomically insert or update
            row = await conn.fetchrow(
                """
                INSERT INTO tts_comparison_ratings (id, variant_id, rating, notes, rated_at)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (variant_id) DO UPDATE SET
                    rating = EXCLUDED.rating,
                    notes = EXCLUDED.notes,
                    rated_at = EXCLUDED.rated_at
                RETURNING id
                """,
                rating.id,
                rating.variant_id,
                rating.rating,
                rating.notes,
                rating.rated_at,
            )
            rating.id = row["id"]
            return rating

    async def get_variant_rating(self, variant_id: UUID) -> Optional[TTSComparisonRating]:
        """Get rating for a variant."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tts_comparison_ratings WHERE variant_id = $1",
                variant_id,
            )
            if row:
                return TTSComparisonRating(
                    id=row["id"],
                    variant_id=row["variant_id"],
                    rating=row["rating"],
                    notes=row["notes"],
                    rated_at=row["rated_at"],
                )
            return None

    async def get_session_ratings(self, session_id: UUID) -> Dict[UUID, TTSComparisonRating]:
        """Get all ratings for a session's variants."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT r.* FROM tts_comparison_ratings r
                JOIN tts_comparison_variants v ON r.variant_id = v.id
                WHERE v.session_id = $1
                """,
                session_id,
            )
            return {
                row["variant_id"]: TTSComparisonRating(
                    id=row["id"],
                    variant_id=row["variant_id"],
                    rating=row["rating"],
                    notes=row["notes"],
                    rated_at=row["rated_at"],
                )
                for row in rows
            }
