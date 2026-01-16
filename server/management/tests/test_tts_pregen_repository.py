# Tests for TTS Pre-Generation Repository
# Database layer tests using mocked asyncpg

import json
import pytest
from datetime import datetime
from typing import Any, Dict, List
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4

from tts_pregen.models import (
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
from tts_pregen.repository import TTSPregenRepository


# =============================================================================
# Fixtures
# =============================================================================


class AsyncContextManagerMock:
    """Mock that properly supports async context manager protocol."""

    def __init__(self, return_value):
        self.return_value = return_value
        self._entered = False

    async def __aenter__(self):
        self._entered = True
        return self.return_value

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        self._entered = False
        return False


@pytest.fixture
def mock_connection():
    """Create a mock asyncpg connection."""
    conn = AsyncMock()
    # Set up default return values
    conn.fetchrow.return_value = None
    conn.fetch.return_value = []
    conn.fetchval.return_value = None
    conn.execute.return_value = None
    return conn


@pytest.fixture
def mock_pool(mock_connection):
    """Create a mock asyncpg pool with proper async context manager support."""
    pool = MagicMock()
    # Configure acquire() to return an async context manager
    pool.acquire.return_value = AsyncContextManagerMock(mock_connection)
    return pool


@pytest.fixture
def repository(mock_pool):
    """Create repository with mock pool."""
    return TTSPregenRepository(mock_pool)


@pytest.fixture
def sample_profile_row():
    """Sample database row for a profile."""
    profile_id = uuid4()
    now = datetime.now()
    return {
        "id": profile_id,
        "name": "Test Profile",
        "description": "A test profile",
        "provider": "chatterbox",
        "voice_id": "nova",
        "settings": json.dumps({"speed": 1.0, "exaggeration": 0.5, "cfg_weight": 0.5}),
        "tags": ["test", "unit"],
        "use_case": "testing",
        "is_active": True,
        "is_default": False,
        "created_at": now,
        "updated_at": now,
        "created_from_session_id": None,
        "sample_audio_path": None,
        "sample_text": "Hello world",
    }


@pytest.fixture
def sample_job_row():
    """Sample database row for a job."""
    job_id = uuid4()
    now = datetime.now()
    return {
        "id": job_id,
        "name": "Test Job",
        "job_type": "batch",
        "status": "pending",
        "source_type": "knowledge-bowl",
        "source_id": None,
        "profile_id": uuid4(),
        "tts_config": None,
        "output_format": "wav",
        "normalize_volume": True,
        "output_dir": "/tmp/tts-output",
        "total_items": 10,
        "completed_items": 0,
        "failed_items": 0,
        "current_item_index": 0,
        "current_item_text": None,
        "created_at": now,
        "started_at": None,
        "paused_at": None,
        "completed_at": None,
        "updated_at": now,
        "last_error": None,
        "consecutive_failures": 0,
    }


@pytest.fixture
def sample_item_row():
    """Sample database row for a job item."""
    return {
        "id": uuid4(),
        "job_id": uuid4(),
        "item_index": 0,
        "text_content": "Test text",
        "text_hash": "abc123",
        "source_ref": "question_1",
        "status": "pending",
        "attempt_count": 0,
        "output_file": None,
        "duration_seconds": None,
        "file_size_bytes": None,
        "sample_rate": None,
        "last_error": None,
        "processing_started_at": None,
        "processing_completed_at": None,
    }


@pytest.fixture
def sample_session_row():
    """Sample database row for a comparison session."""
    session_id = uuid4()
    now = datetime.now()
    return {
        "id": session_id,
        "name": "Test Session",
        "description": "A test session",
        "status": "draft",
        "config": json.dumps({
            "samples": [{"text": "Hello", "source_ref": "q1"}],
            "configurations": [{"name": "Config 1", "provider": "chatterbox", "voice_id": "nova", "settings": {}}]
        }),
        "created_at": now,
        "updated_at": now,
    }


@pytest.fixture
def sample_variant_row():
    """Sample database row for a comparison variant."""
    return {
        "id": uuid4(),
        "session_id": uuid4(),
        "sample_index": 0,
        "config_index": 0,
        "text_content": "Test text",
        "tts_config": json.dumps({"provider": "chatterbox", "voice_id": "nova"}),
        "status": "pending",
        "output_file": None,
        "duration_seconds": None,
        "last_error": None,
    }


@pytest.fixture
def sample_rating_row():
    """Sample database row for a rating."""
    return {
        "id": uuid4(),
        "variant_id": uuid4(),
        "rating": 4,
        "notes": "Good quality",
        "rated_at": datetime.now(),
    }


# =============================================================================
# Profile Tests
# =============================================================================


class TestProfileOperations:
    """Tests for profile database operations."""

    @pytest.mark.asyncio
    async def test_create_profile(self, repository, mock_connection):
        """Test creating a profile."""
        profile = TTSProfile.create(
            name="Test Profile",
            provider="chatterbox",
            voice_id="nova",
            settings=TTSProfileSettings(speed=1.0),
        )

        result = await repository.create_profile(profile)

        assert result == profile
        mock_connection.execute.assert_called_once()
        # Verify the INSERT query was called with correct parameters
        call_args = mock_connection.execute.call_args
        assert "INSERT INTO tts_profiles" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_get_profile_found(self, repository, mock_connection, sample_profile_row):
        """Test getting a profile that exists."""
        mock_connection.fetchrow.return_value = sample_profile_row

        profile_id = sample_profile_row["id"]
        result = await repository.get_profile(profile_id)

        assert result is not None
        assert result.id == profile_id
        assert result.name == "Test Profile"
        assert result.provider == "chatterbox"
        mock_connection.fetchrow.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_profile_not_found(self, repository, mock_connection):
        """Test getting a profile that doesn't exist."""
        mock_connection.fetchrow.return_value = None

        result = await repository.get_profile(uuid4())

        assert result is None

    @pytest.mark.asyncio
    async def test_get_profile_by_name(self, repository, mock_connection, sample_profile_row):
        """Test getting a profile by name."""
        mock_connection.fetchrow.return_value = sample_profile_row

        result = await repository.get_profile_by_name("Test Profile")

        assert result is not None
        assert result.name == "Test Profile"
        mock_connection.fetchrow.assert_called_once()

    @pytest.mark.asyncio
    async def test_list_profiles_no_filters(self, repository, mock_connection, sample_profile_row):
        """Test listing profiles without filters."""
        mock_connection.fetchval.return_value = 1
        mock_connection.fetch.return_value = [sample_profile_row]

        profiles, total = await repository.list_profiles()

        assert len(profiles) == 1
        assert total == 1
        assert profiles[0].name == "Test Profile"

    @pytest.mark.asyncio
    async def test_list_profiles_with_provider_filter(self, repository, mock_connection, sample_profile_row):
        """Test listing profiles with provider filter."""
        mock_connection.fetchval.return_value = 1
        mock_connection.fetch.return_value = [sample_profile_row]

        profiles, total = await repository.list_profiles(provider="chatterbox")

        assert len(profiles) == 1
        # Verify provider filter was included in query
        query_call = mock_connection.fetch.call_args[0][0]
        assert "provider = $" in query_call

    @pytest.mark.asyncio
    async def test_list_profiles_with_tags_filter(self, repository, mock_connection, sample_profile_row):
        """Test listing profiles with tags filter."""
        mock_connection.fetchval.return_value = 1
        mock_connection.fetch.return_value = [sample_profile_row]

        profiles, total = await repository.list_profiles(tags=["test"])

        assert len(profiles) == 1
        # Verify tags filter was included (PostgreSQL array overlap operator)
        query_call = mock_connection.fetch.call_args[0][0]
        assert "tags && $" in query_call

    @pytest.mark.asyncio
    async def test_update_profile(self, repository, mock_connection):
        """Test updating a profile."""
        profile = TTSProfile.create(
            name="Test Profile",
            provider="chatterbox",
            voice_id="nova",
            settings=TTSProfileSettings(speed=1.0),
        )

        result = await repository.update_profile(profile)

        assert result.updated_at is not None
        mock_connection.execute.assert_called_once()
        call_args = mock_connection.execute.call_args
        assert "UPDATE tts_profiles SET" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_delete_profile_soft(self, repository, mock_connection):
        """Test soft deleting a profile."""
        mock_connection.execute.return_value = "UPDATE 1"

        profile_id = uuid4()
        result = await repository.delete_profile(profile_id, soft=True)

        assert result is True
        call_args = mock_connection.execute.call_args
        assert "is_active = FALSE" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_delete_profile_hard(self, repository, mock_connection):
        """Test hard deleting a profile."""
        mock_connection.execute.return_value = "DELETE 1"

        profile_id = uuid4()
        result = await repository.delete_profile(profile_id, soft=False)

        assert result is True
        call_args = mock_connection.execute.call_args
        assert "DELETE FROM tts_profiles" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_delete_profile_not_found(self, repository, mock_connection):
        """Test deleting a profile that doesn't exist."""
        mock_connection.execute.return_value = "DELETE 0"

        profile_id = uuid4()
        result = await repository.delete_profile(profile_id, soft=False)

        assert result is False

    @pytest.mark.asyncio
    async def test_set_default_profile(self, repository, mock_connection):
        """Test setting a default profile."""
        profile_id = uuid4()
        await repository.set_default_profile(profile_id)

        # Should have cleared existing default and set new one
        assert mock_connection.execute.call_count == 2

    def test_row_to_profile_with_dict_settings(self, repository, sample_profile_row):
        """Test converting row with dict settings."""
        sample_profile_row["settings"] = {"speed": 1.0, "exaggeration": 0.5}

        result = repository._row_to_profile(sample_profile_row)

        assert result.settings.speed == 1.0
        assert result.settings.exaggeration == 0.5

    def test_row_to_profile_with_json_settings(self, repository, sample_profile_row):
        """Test converting row with JSON string settings."""
        sample_profile_row["settings"] = json.dumps({"speed": 1.2})

        result = repository._row_to_profile(sample_profile_row)

        assert result.settings.speed == 1.2


# =============================================================================
# Module Profile Association Tests
# =============================================================================


class TestModuleProfileOperations:
    """Tests for module-profile association operations."""

    @pytest.mark.asyncio
    async def test_assign_profile_to_module(self, repository, mock_connection):
        """Test assigning a profile to a module."""
        profile_id = uuid4()
        assoc = await repository.assign_profile_to_module(
            module_id="knowledge-bowl",
            profile_id=profile_id,
            context="questions",
            priority=10,
        )

        assert assoc.module_id == "knowledge-bowl"
        assert assoc.profile_id == profile_id
        assert assoc.context == "questions"
        assert assoc.priority == 10
        mock_connection.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_assign_profile_upsert(self, repository, mock_connection):
        """Test that assignment uses upsert for conflict handling."""
        await repository.assign_profile_to_module(
            module_id="test-module",
            profile_id=uuid4(),
        )

        call_args = mock_connection.execute.call_args
        assert "ON CONFLICT" in call_args[0][0]
        assert "DO UPDATE SET" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_remove_profile_from_module(self, repository, mock_connection):
        """Test removing a profile from a module."""
        mock_connection.execute.return_value = "DELETE 1"

        result = await repository.remove_profile_from_module("test-module", uuid4())

        assert result is True
        call_args = mock_connection.execute.call_args
        assert "DELETE FROM tts_module_profiles" in call_args[0][0]


# =============================================================================
# Job Tests
# =============================================================================


class TestJobOperations:
    """Tests for job database operations."""

    @pytest.mark.asyncio
    async def test_create_job(self, repository, mock_connection):
        """Test creating a job."""
        job = TTSPregenJob.create(
            name="Test Job",
            source_type="knowledge-bowl",
            output_dir="/tmp/output",
        )

        result = await repository.create_job(job)

        assert result == job
        mock_connection.execute.assert_called_once()
        call_args = mock_connection.execute.call_args
        assert "INSERT INTO tts_pregen_jobs" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_get_job_found(self, repository, mock_connection, sample_job_row):
        """Test getting a job that exists."""
        mock_connection.fetchrow.return_value = sample_job_row

        result = await repository.get_job(sample_job_row["id"])

        assert result is not None
        assert result.name == "Test Job"
        assert result.status == JobStatus.PENDING

    @pytest.mark.asyncio
    async def test_get_job_not_found(self, repository, mock_connection):
        """Test getting a job that doesn't exist."""
        mock_connection.fetchrow.return_value = None

        result = await repository.get_job(uuid4())

        assert result is None

    @pytest.mark.asyncio
    async def test_list_jobs_no_filters(self, repository, mock_connection, sample_job_row):
        """Test listing jobs without filters."""
        mock_connection.fetchval.return_value = 1
        mock_connection.fetch.return_value = [sample_job_row]

        jobs, total = await repository.list_jobs()

        assert len(jobs) == 1
        assert total == 1

    @pytest.mark.asyncio
    async def test_list_jobs_with_status_filter(self, repository, mock_connection, sample_job_row):
        """Test listing jobs with status filter."""
        mock_connection.fetchval.return_value = 1
        mock_connection.fetch.return_value = [sample_job_row]

        jobs, total = await repository.list_jobs(status=JobStatus.PENDING)

        assert len(jobs) == 1

    @pytest.mark.asyncio
    async def test_update_job(self, repository, mock_connection, sample_job_row):
        """Test updating a job."""
        job = repository._row_to_job(sample_job_row)
        job.completed_items = 5

        result = await repository.update_job(job)

        assert result.completed_items == 5
        mock_connection.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_update_job_status_running(self, repository, mock_connection):
        """Test updating job status to running."""
        await repository.update_job_status(uuid4(), JobStatus.RUNNING)

        call_args = mock_connection.execute.call_args
        assert "started_at" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_update_job_status_paused(self, repository, mock_connection):
        """Test updating job status to paused."""
        await repository.update_job_status(uuid4(), JobStatus.PAUSED)

        call_args = mock_connection.execute.call_args
        assert "paused_at" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_update_job_status_completed(self, repository, mock_connection):
        """Test updating job status to completed."""
        await repository.update_job_status(uuid4(), JobStatus.COMPLETED)

        call_args = mock_connection.execute.call_args
        assert "completed_at" in call_args[0][0]

    def test_row_to_job_with_json_config(self, repository, sample_job_row):
        """Test converting row with JSON config."""
        sample_job_row["tts_config"] = json.dumps({"provider": "chatterbox"})

        result = repository._row_to_job(sample_job_row)

        assert result.tts_config == {"provider": "chatterbox"}

    def test_row_to_job_with_dict_config(self, repository, sample_job_row):
        """Test converting row with dict config."""
        sample_job_row["tts_config"] = {"provider": "vibevoice"}

        result = repository._row_to_job(sample_job_row)

        assert result.tts_config == {"provider": "vibevoice"}


# =============================================================================
# Job Item Tests
# =============================================================================


class TestJobItemOperations:
    """Tests for job item database operations."""

    @pytest.mark.asyncio
    async def test_create_job_items(self, repository, mock_connection):
        """Test bulk creating job items."""
        job_id = uuid4()
        items = [
            TTSJobItem.create(job_id, 0, "Text 1", "hash1"),
            TTSJobItem.create(job_id, 1, "Text 2", "hash2"),
        ]

        count = await repository.create_job_items(items)

        assert count == 2
        mock_connection.executemany.assert_called_once()

    @pytest.mark.asyncio
    async def test_create_job_items_empty(self, repository, mock_pool):
        """Test creating empty list of items."""
        count = await repository.create_job_items([])

        assert count == 0
        mock_pool.acquire.assert_not_called()

    @pytest.mark.asyncio
    async def test_get_job_items(self, repository, mock_connection, sample_item_row):
        """Test getting job items."""
        mock_connection.fetch.return_value = [sample_item_row]

        items = await repository.get_job_items(uuid4())

        assert len(items) == 1
        assert items[0].text_content == "Test text"

    @pytest.mark.asyncio
    async def test_get_job_items_with_status(self, repository, mock_connection, sample_item_row):
        """Test getting job items with status filter."""
        mock_connection.fetch.return_value = [sample_item_row]

        items = await repository.get_job_items(uuid4(), status=ItemStatus.PENDING)

        assert len(items) == 1
        # Verify status filter was included
        call_args = mock_connection.fetch.call_args
        assert "status = $" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_get_pending_items(self, repository, mock_connection, sample_item_row):
        """Test getting pending items."""
        mock_connection.fetch.return_value = [sample_item_row]

        items = await repository.get_pending_items(uuid4())

        assert len(items) == 1
        call_args = mock_connection.fetch.call_args
        assert "status = 'pending'" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_update_item_status_processing(self, repository, mock_connection):
        """Test updating item to processing."""
        await repository.update_item_status(uuid4(), ItemStatus.PROCESSING)

        call_args = mock_connection.execute.call_args
        assert "processing_started_at" in call_args[0][0]
        assert "attempt_count = attempt_count + 1" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_update_item_status_completed(self, repository, mock_connection):
        """Test updating item to completed."""
        await repository.update_item_status(
            uuid4(),
            ItemStatus.COMPLETED,
            output_file="/path/to/audio.wav",
            duration_seconds=2.5,
            file_size_bytes=50000,
            sample_rate=22050,
        )

        call_args = mock_connection.execute.call_args
        assert "output_file = $" in call_args[0][0]
        assert "duration_seconds = $" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_update_item_status_failed(self, repository, mock_connection):
        """Test updating item to failed."""
        await repository.update_item_status(
            uuid4(),
            ItemStatus.FAILED,
            error="TTS generation failed",
        )

        call_args = mock_connection.execute.call_args
        assert "last_error = $" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_reset_failed_items(self, repository, mock_connection):
        """Test resetting failed items."""
        mock_connection.execute.return_value = "UPDATE 3"

        count = await repository.reset_failed_items(uuid4())

        assert count == 3
        call_args = mock_connection.execute.call_args
        assert "status = 'pending'" in call_args[0][0]
        assert "status = 'failed'" in call_args[0][0]


# =============================================================================
# Comparison Session Tests
# =============================================================================


class TestComparisonSessionOperations:
    """Tests for comparison session database operations."""

    @pytest.mark.asyncio
    async def test_create_session(self, repository, mock_connection):
        """Test creating a session."""
        session = TTSComparisonSession.create(
            name="Test Session",
            samples=[{"text": "Hello", "source_ref": "test"}],
            configurations=[{"name": "Test Config", "provider": "chatterbox", "voice_id": "nova", "settings": {}}],
        )

        result = await repository.create_session(session)

        assert result == session
        mock_connection.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_session_found(self, repository, mock_connection, sample_session_row):
        """Test getting a session that exists."""
        mock_connection.fetchrow.return_value = sample_session_row

        result = await repository.get_session(sample_session_row["id"])

        assert result is not None
        assert result.name == "Test Session"
        assert result.status == SessionStatus.DRAFT

    @pytest.mark.asyncio
    async def test_get_session_not_found(self, repository, mock_connection):
        """Test getting a session that doesn't exist."""
        mock_connection.fetchrow.return_value = None

        result = await repository.get_session(uuid4())

        assert result is None

    @pytest.mark.asyncio
    async def test_list_sessions_no_filter(self, repository, mock_connection, sample_session_row):
        """Test listing sessions without filter."""
        mock_connection.fetchval.return_value = 1
        mock_connection.fetch.return_value = [sample_session_row]

        sessions, total = await repository.list_sessions()

        assert len(sessions) == 1
        assert total == 1

    @pytest.mark.asyncio
    async def test_list_sessions_with_status(self, repository, mock_connection, sample_session_row):
        """Test listing sessions with status filter."""
        mock_connection.fetchval.return_value = 1
        mock_connection.fetch.return_value = [sample_session_row]

        sessions, total = await repository.list_sessions(status=SessionStatus.DRAFT)

        assert len(sessions) == 1

    @pytest.mark.asyncio
    async def test_update_session_status(self, repository, mock_connection):
        """Test updating session status."""
        await repository.update_session_status(uuid4(), SessionStatus.GENERATING)

        mock_connection.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_delete_session(self, repository, mock_connection):
        """Test deleting a session."""
        mock_connection.execute.return_value = "DELETE 1"

        result = await repository.delete_session(uuid4())

        assert result is True


# =============================================================================
# Comparison Variant Tests
# =============================================================================


class TestComparisonVariantOperations:
    """Tests for comparison variant database operations."""

    @pytest.mark.asyncio
    async def test_create_variants(self, repository, mock_connection):
        """Test bulk creating variants."""
        session_id = uuid4()
        variants = [
            TTSComparisonVariant.create(
                session_id, 0, 0, "Test text",
                {"provider": "chatterbox", "voice_id": "nova"}
            ),
        ]

        count = await repository.create_variants(variants)

        assert count == 1
        mock_connection.executemany.assert_called_once()

    @pytest.mark.asyncio
    async def test_create_variants_empty(self, repository, mock_pool):
        """Test creating empty list of variants."""
        count = await repository.create_variants([])

        assert count == 0

    @pytest.mark.asyncio
    async def test_get_session_variants(self, repository, mock_connection, sample_variant_row):
        """Test getting session variants."""
        mock_connection.fetch.return_value = [sample_variant_row]

        variants = await repository.get_session_variants(uuid4())

        assert len(variants) == 1
        assert variants[0].text_content == "Test text"

    @pytest.mark.asyncio
    async def test_get_variant_found(self, repository, mock_connection, sample_variant_row):
        """Test getting a variant that exists."""
        mock_connection.fetchrow.return_value = sample_variant_row

        result = await repository.get_variant(sample_variant_row["id"])

        assert result is not None
        assert result.status == VariantStatus.PENDING

    @pytest.mark.asyncio
    async def test_get_variant_not_found(self, repository, mock_connection):
        """Test getting a variant that doesn't exist."""
        mock_connection.fetchrow.return_value = None

        result = await repository.get_variant(uuid4())

        assert result is None

    @pytest.mark.asyncio
    async def test_update_variant_status(self, repository, mock_connection):
        """Test updating variant status."""
        await repository.update_variant_status(
            uuid4(),
            VariantStatus.READY,
            output_file="/path/to/audio.wav",
            duration_seconds=2.5,
        )

        mock_connection.execute.assert_called_once()


# =============================================================================
# Rating Tests
# =============================================================================


class TestRatingOperations:
    """Tests for rating database operations."""

    @pytest.mark.asyncio
    async def test_create_rating_new(self, repository, mock_connection):
        """Test creating a new rating."""
        mock_connection.fetchrow.return_value = None  # No existing rating

        rating = TTSComparisonRating.create(uuid4(), rating=4, notes="Good")
        result = await repository.create_or_update_rating(rating)

        assert result == rating
        # Should have called INSERT
        calls = mock_connection.execute.call_args_list
        assert len(calls) == 1
        assert "INSERT INTO tts_comparison_ratings" in calls[0][0][0]

    @pytest.mark.asyncio
    async def test_update_existing_rating(self, repository, mock_connection):
        """Test updating an existing rating."""
        existing_id = uuid4()
        mock_connection.fetchrow.return_value = {"id": existing_id}

        rating = TTSComparisonRating.create(uuid4(), rating=5, notes="Excellent")
        result = await repository.create_or_update_rating(rating)

        assert result.id == existing_id
        # Should have called UPDATE
        calls = mock_connection.execute.call_args_list
        assert len(calls) == 1
        assert "UPDATE tts_comparison_ratings" in calls[0][0][0]

    @pytest.mark.asyncio
    async def test_get_variant_rating_found(self, repository, mock_connection, sample_rating_row):
        """Test getting a rating that exists."""
        mock_connection.fetchrow.return_value = sample_rating_row

        result = await repository.get_variant_rating(sample_rating_row["variant_id"])

        assert result is not None
        assert result.rating == 4
        assert result.notes == "Good quality"

    @pytest.mark.asyncio
    async def test_get_variant_rating_not_found(self, repository, mock_connection):
        """Test getting a rating that doesn't exist."""
        mock_connection.fetchrow.return_value = None

        result = await repository.get_variant_rating(uuid4())

        assert result is None

    @pytest.mark.asyncio
    async def test_get_session_ratings(self, repository, mock_connection, sample_rating_row):
        """Test getting all ratings for a session."""
        mock_connection.fetch.return_value = [sample_rating_row]

        ratings = await repository.get_session_ratings(uuid4())

        assert len(ratings) == 1
        variant_id = sample_rating_row["variant_id"]
        assert variant_id in ratings
        assert ratings[variant_id].rating == 4
