"""
Tests for Knowledge Bowl Audio Manager

Tests for the KB audio pre-generation system including segment extraction,
manifest management, coverage tracking, and audio retrieval.
"""

import asyncio
import json
import pytest
from datetime import datetime
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

from tts_cache.kb_audio import (
    KBAudioManager,
    KBSegmentType,
    KBSegment,
    KBAudioEntry,
    KBManifest,
    KBPrefetchProgress,
    KBCoverageStatus,
    _validate_path_component,
)


# =============================================================================
# FIXTURES
# =============================================================================


@pytest.fixture
def tmp_kb_dir(tmp_path):
    """Create temporary directory for KB audio."""
    return tmp_path / "kb_audio"


@pytest.fixture
def mock_resource_pool():
    """Create a mock TTS resource pool."""
    pool = MagicMock()
    pool.request_generation = AsyncMock(return_value=b"RIFF" + b"\x00" * 100)
    return pool


@pytest.fixture
async def kb_manager(tmp_kb_dir, mock_resource_pool):
    """Create a KBAudioManager instance."""
    manager = KBAudioManager(
        base_dir=str(tmp_kb_dir),
        resource_pool=mock_resource_pool,
        delay_between_requests=0.0,  # No delay for tests
    )
    await manager.initialize()
    return manager


@pytest.fixture
def sample_module_content():
    """Create sample KB module content."""
    return {
        "domains": [
            {
                "id": "science",
                "name": "Science",
                "questions": [
                    {
                        "id": "sci-001",
                        "question_text": "What is the speed of light?",
                        "answer_text": "300 million meters per second",
                        "hints": ["Think about physics", "It's very fast"],
                        "explanation": "Light travels at approximately 3x10^8 m/s.",
                    },
                    {
                        "id": "sci-002",
                        "question_text": "What is H2O?",
                        "answer_text": "Water",
                        "hints": ["Common substance"],
                        "explanation": "H2O is the chemical formula for water.",
                    },
                ],
            },
            {
                "id": "math",
                "name": "Mathematics",
                "questions": [
                    {
                        "id": "math-001",
                        "question_text": "What is 2+2?",
                        "answer_text": "4",
                        "hints": [],
                        "explanation": "Basic addition.",
                    },
                ],
            },
        ]
    }


# =============================================================================
# DATA CLASS TESTS
# =============================================================================


class TestKBSegmentType:
    """Tests for KBSegmentType enum."""

    def test_segment_types_exist(self):
        """Test all segment types are defined."""
        assert KBSegmentType.QUESTION.value == "question"
        assert KBSegmentType.ANSWER.value == "answer"
        assert KBSegmentType.HINT.value == "hint"
        assert KBSegmentType.EXPLANATION.value == "explanation"


class TestKBSegment:
    """Tests for KBSegment dataclass."""

    def test_segment_creation(self):
        """Test creating a segment."""
        segment = KBSegment(
            question_id="sci-001",
            segment_type=KBSegmentType.QUESTION,
            text="What is light?",
        )
        assert segment.question_id == "sci-001"
        assert segment.segment_type == KBSegmentType.QUESTION
        assert segment.text == "What is light?"
        assert segment.hint_index == 0

    def test_segment_filename_question(self):
        """Test filename for question segment."""
        segment = KBSegment(
            question_id="sci-001",
            segment_type=KBSegmentType.QUESTION,
            text="What is light?",
        )
        assert segment.filename == "question.wav"

    def test_segment_filename_hint(self):
        """Test filename for hint segment with index."""
        segment = KBSegment(
            question_id="sci-001",
            segment_type=KBSegmentType.HINT,
            text="Think about it",
            hint_index=2,
        )
        assert segment.filename == "hint_2.wav"


class TestKBAudioEntry:
    """Tests for KBAudioEntry dataclass."""

    def test_entry_to_dict(self):
        """Test converting entry to dict."""
        entry = KBAudioEntry(
            question_id="sci-001",
            segment_type="question",
            file_path="/path/to/file.wav",
            size_bytes=1024,
            duration_seconds=5.5,
            sample_rate=24000,
            created_at=datetime(2024, 1, 15, 12, 0, 0),
        )
        d = entry.to_dict()
        assert d["question_id"] == "sci-001"
        assert d["segment_type"] == "question"
        assert d["size_bytes"] == 1024
        assert d["duration_seconds"] == 5.5
        assert d["sample_rate"] == 24000

    def test_entry_from_dict(self):
        """Test creating entry from dict."""
        d = {
            "question_id": "sci-001",
            "segment_type": "question",
            "file_path": "/path/to/file.wav",
            "size_bytes": 1024,
            "duration_seconds": 5.5,
            "sample_rate": 24000,
            "created_at": "2024-01-15T12:00:00",
            "hint_index": 0,
        }
        entry = KBAudioEntry.from_dict(d)
        assert entry.question_id == "sci-001"
        assert entry.size_bytes == 1024


class TestKBManifest:
    """Tests for KBManifest dataclass."""

    def test_manifest_creation(self):
        """Test creating a manifest."""
        manifest = KBManifest(
            module_id="knowledge-bowl",
            voice_id="nova",
            provider="vibevoice",
            generated_at=datetime.now(),
        )
        assert manifest.module_id == "knowledge-bowl"
        assert manifest.total_questions == 0
        assert manifest.total_segments == 0

    def test_manifest_to_dict_and_back(self):
        """Test manifest serialization round-trip."""
        manifest = KBManifest(
            module_id="knowledge-bowl",
            voice_id="nova",
            provider="vibevoice",
            generated_at=datetime(2024, 1, 15, 12, 0, 0),
            total_questions=10,
            total_segments=40,
            total_size_bytes=102400,
            total_duration_seconds=300.0,
        )
        d = manifest.to_dict()
        restored = KBManifest.from_dict(d)
        assert restored.module_id == manifest.module_id
        assert restored.total_questions == manifest.total_questions


class TestKBPrefetchProgress:
    """Tests for KBPrefetchProgress dataclass."""

    def test_progress_to_dict(self):
        """Test progress serialization."""
        progress = KBPrefetchProgress(
            job_id="job_123",
            module_id="knowledge-bowl",
            total_segments=100,
            completed=50,
            generated=45,
            cached=5,
            failed=0,
            status="in_progress",
            started_at=datetime(2024, 1, 15, 12, 0, 0),
        )
        d = progress.to_dict()
        assert d["job_id"] == "job_123"
        assert d["completed"] == 50
        assert d["percent_complete"] == 50.0


class TestKBCoverageStatus:
    """Tests for KBCoverageStatus dataclass."""

    def test_coverage_full(self):
        """Test full coverage status."""
        status = KBCoverageStatus(
            module_id="knowledge-bowl",
            total_questions=10,
            covered_questions=10,
            total_segments=40,
            covered_segments=40,
            missing_segments=0,
            total_size_bytes=100000,
            is_complete=True,
        )
        d = status.to_dict()
        assert d["is_complete"] is True
        assert d["covered_segments"] == 40

    def test_coverage_partial(self):
        """Test partial coverage status."""
        status = KBCoverageStatus(
            module_id="knowledge-bowl",
            total_questions=10,
            covered_questions=7,
            total_segments=40,
            covered_segments=30,
            missing_segments=10,
            total_size_bytes=75000,
            is_complete=False,
        )
        d = status.to_dict()
        assert d["is_complete"] is False
        assert d["covered_segments"] == 30


# =============================================================================
# KB AUDIO MANAGER TESTS
# =============================================================================


class TestKBAudioManagerInit:
    """Tests for KBAudioManager initialization."""

    @pytest.mark.asyncio
    async def test_init_creates_directories(self, tmp_kb_dir, mock_resource_pool):
        """Test that initialization creates required directories."""
        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        assert tmp_kb_dir.exists()
        assert (tmp_kb_dir / "feedback").exists()

    @pytest.mark.asyncio
    async def test_init_loads_existing_manifests(self, tmp_kb_dir, mock_resource_pool):
        """Test that initialization loads existing manifests."""
        # Create a manifest file
        module_dir = tmp_kb_dir / "test-module"
        module_dir.mkdir(parents=True)
        manifest_data = {
            "module_id": "test-module",
            "voice_id": "nova",
            "provider": "vibevoice",
            "generated_at": "2024-01-15T12:00:00",
            "total_questions": 5,
            "total_segments": 20,
            "total_size_bytes": 10000,
            "total_duration_seconds": 60.0,
            "segments": {},
        }
        with open(module_dir / "manifest.json", "w") as f:
            json.dump(manifest_data, f)

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        assert "test-module" in manager._manifests


class TestKBAudioManagerExtractSegments:
    """Tests for segment extraction."""

    @pytest.mark.asyncio
    async def test_extract_segments_basic(self, kb_manager, sample_module_content):
        """Test basic segment extraction."""
        segments = kb_manager.extract_segments(sample_module_content)

        # sci-001: question, answer, 2 hints, explanation = 5
        # sci-002: question, answer, 1 hint, explanation = 4
        # math-001: question, answer, 0 hints, explanation = 3
        # Total = 12
        assert len(segments) == 12

    @pytest.mark.asyncio
    async def test_extract_segments_types(self, kb_manager, sample_module_content):
        """Test that all segment types are extracted."""
        segments = kb_manager.extract_segments(sample_module_content)

        types = {s.segment_type for s in segments}
        assert KBSegmentType.QUESTION in types
        assert KBSegmentType.ANSWER in types
        assert KBSegmentType.HINT in types
        assert KBSegmentType.EXPLANATION in types

    @pytest.mark.asyncio
    async def test_extract_segments_empty_module(self, kb_manager):
        """Test extraction from empty module."""
        segments = kb_manager.extract_segments({"domains": []})
        assert len(segments) == 0


class TestKBAudioManagerCoverage:
    """Tests for coverage tracking."""

    @pytest.mark.asyncio
    async def test_coverage_no_audio(self, kb_manager, sample_module_content):
        """Test coverage when no audio exists."""
        status = kb_manager.get_coverage_status("test-module", sample_module_content)

        assert status.total_segments == 12
        assert status.covered_segments == 0
        assert status.is_complete is False

    @pytest.mark.asyncio
    async def test_coverage_with_manifest(self, tmp_kb_dir, mock_resource_pool, sample_module_content):
        """Test coverage when manifest exists with some audio."""
        # Create module directory and manifest
        module_dir = tmp_kb_dir / "test-module"
        module_dir.mkdir(parents=True)

        # Create manifest with some segments covered
        manifest_data = {
            "module_id": "test-module",
            "voice_id": "nova",
            "provider": "vibevoice",
            "generated_at": "2024-01-15T12:00:00",
            "total_questions": 3,
            "total_segments": 6,
            "total_size_bytes": 10000,
            "total_duration_seconds": 60.0,
            "segments": {
                "sci-001": {
                    "question": {
                        "question_id": "sci-001",
                        "segment_type": "question",
                        "file_path": "/path/q.wav",
                        "size_bytes": 1000,
                        "duration_seconds": 5.0,
                        "sample_rate": 24000,
                        "created_at": "2024-01-15T12:00:00",
                        "hint_index": 0,
                    },
                    "answer": {
                        "question_id": "sci-001",
                        "segment_type": "answer",
                        "file_path": "/path/a.wav",
                        "size_bytes": 500,
                        "duration_seconds": 2.0,
                        "sample_rate": 24000,
                        "created_at": "2024-01-15T12:00:00",
                        "hint_index": 0,
                    },
                },
            },
        }
        with open(module_dir / "manifest.json", "w") as f:
            json.dump(manifest_data, f)

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        # Check the manifest was loaded
        status = manager.get_coverage_status("test-module", sample_module_content)
        # Coverage depends on whether manifest entries match actual segments
        assert status.total_segments == 12


class TestKBAudioManagerGetAudio:
    """Tests for audio retrieval."""

    @pytest.mark.asyncio
    async def test_get_audio_not_found(self, kb_manager):
        """Test getting audio that doesn't exist."""
        audio = await kb_manager.get_audio(
            module_id="test-module",
            question_id="sci-001",
            segment_type="question",
        )
        assert audio is None

    @pytest.mark.asyncio
    async def test_get_audio_exists(self, tmp_kb_dir, mock_resource_pool):
        """Test getting audio that exists."""
        # Create the audio file
        module_dir = tmp_kb_dir / "test-module" / "sci-001"
        module_dir.mkdir(parents=True)
        audio_path = module_dir / "question.wav"
        audio_data = b"RIFF" + b"\x00" * 100
        audio_path.write_bytes(audio_data)

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        audio = await manager.get_audio(
            module_id="test-module",
            question_id="sci-001",
            segment_type="question",
        )
        assert audio == audio_data


class TestKBAudioManagerManifest:
    """Tests for manifest management."""

    @pytest.mark.asyncio
    async def test_get_manifest_not_exists(self, kb_manager):
        """Test getting manifest that doesn't exist."""
        manifest = await kb_manager.get_manifest("nonexistent-module")
        assert manifest is None

    @pytest.mark.asyncio
    async def test_get_manifest_exists(self, tmp_kb_dir, mock_resource_pool):
        """Test getting existing manifest."""
        # Create manifest
        module_dir = tmp_kb_dir / "test-module"
        module_dir.mkdir(parents=True)
        manifest_data = {
            "module_id": "test-module",
            "voice_id": "nova",
            "provider": "vibevoice",
            "generated_at": "2024-01-15T12:00:00",
            "total_questions": 5,
            "total_segments": 20,
            "total_size_bytes": 10000,
            "total_duration_seconds": 60.0,
            "segments": {},
        }
        with open(module_dir / "manifest.json", "w") as f:
            json.dump(manifest_data, f)

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        manifest = await manager.get_manifest("test-module")
        assert manifest is not None
        assert manifest.module_id == "test-module"


class TestKBAudioManagerProgress:
    """Tests for job progress tracking."""

    @pytest.mark.asyncio
    async def test_get_progress_no_job(self, kb_manager):
        """Test getting progress for non-existent job."""
        progress = kb_manager.get_progress("nonexistent-job")
        assert progress is None


class TestKBAudioManagerFeedback:
    """Tests for feedback audio."""

    @pytest.mark.asyncio
    async def test_get_feedback_not_exists(self, kb_manager):
        """Test getting feedback audio that doesn't exist."""
        audio = await kb_manager.get_feedback_audio("correct")
        assert audio is None

    @pytest.mark.asyncio
    async def test_get_feedback_exists(self, tmp_kb_dir, mock_resource_pool):
        """Test getting existing feedback audio."""
        # Create feedback directory and file
        feedback_dir = tmp_kb_dir / "feedback"
        feedback_dir.mkdir(parents=True)
        audio_data = b"RIFF" + b"\x00" * 50
        (feedback_dir / "correct.wav").write_bytes(audio_data)

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        audio = await manager.get_feedback_audio("correct")
        assert audio == audio_data


class TestKBAudioManagerDuration:
    """Tests for duration estimation."""

    @pytest.mark.asyncio
    async def test_estimate_duration(self, kb_manager):
        """Test duration estimation from file size."""
        # 24kHz, 16-bit (2 bytes per sample) = 48000 bytes per second
        size_bytes = 48000  # Should be ~1 second
        duration = kb_manager._estimate_duration(size_bytes)
        assert abs(duration - 1.0) < 0.1


# =============================================================================
# PATH VALIDATION TESTS (Security Critical)
# =============================================================================


class TestValidatePathComponent:
    """Tests for _validate_path_component security function."""

    def test_valid_simple_name(self):
        """Test valid simple names pass validation."""
        assert _validate_path_component("question-001") is True
        assert _validate_path_component("sci_phys") is True
        assert _validate_path_component("kb-2024") is True
        assert _validate_path_component("a") is True
        assert _validate_path_component("test123") is True

    def test_empty_string_rejected(self):
        """Test empty string is rejected."""
        assert _validate_path_component("") is False

    def test_path_traversal_rejected(self):
        """Test path traversal attempts are rejected."""
        assert _validate_path_component("..") is False
        assert _validate_path_component("../etc/passwd") is False
        assert _validate_path_component("foo/../bar") is False
        assert _validate_path_component("..hidden") is False

    def test_forward_slash_rejected(self):
        """Test forward slashes are rejected."""
        assert _validate_path_component("path/to/file") is False
        assert _validate_path_component("/tmp/foo") is False
        assert _validate_path_component("foo/") is False

    def test_backslash_rejected(self):
        """Test backslashes are rejected."""
        assert _validate_path_component("path\\to\\file") is False
        assert _validate_path_component("C:\\windows") is False
        assert _validate_path_component("foo\\") is False

    def test_absolute_paths_rejected(self):
        """Test absolute paths are rejected."""
        assert _validate_path_component("/tmp/foo") is False
        assert _validate_path_component("/etc/passwd") is False


class TestPathTraversalPrevention:
    """Tests for path traversal prevention in get_audio and get_feedback_audio."""

    @pytest.mark.asyncio
    async def test_get_audio_rejects_path_traversal_module_id(self, kb_manager):
        """Test that path traversal in module_id is rejected."""
        audio = await kb_manager.get_audio(
            module_id="../etc",
            question_id="passwd",
            segment_type="question",
        )
        assert audio is None

    @pytest.mark.asyncio
    async def test_get_audio_rejects_path_traversal_question_id(self, kb_manager):
        """Test that path traversal in question_id is rejected."""
        audio = await kb_manager.get_audio(
            module_id="test-module",
            question_id="../../../etc/passwd",
            segment_type="question",
        )
        assert audio is None

    @pytest.mark.asyncio
    async def test_get_audio_rejects_absolute_path(self, kb_manager):
        """Test that absolute paths are rejected."""
        audio = await kb_manager.get_audio(
            module_id="/etc",
            question_id="passwd",
            segment_type="question",
        )
        assert audio is None

    @pytest.mark.asyncio
    async def test_get_feedback_rejects_path_traversal(self, kb_manager):
        """Test that path traversal in feedback_type is rejected."""
        audio = await kb_manager.get_feedback_audio("../../../etc/passwd")
        assert audio is None

    @pytest.mark.asyncio
    async def test_get_feedback_rejects_empty(self, kb_manager):
        """Test that empty feedback_type is rejected."""
        audio = await kb_manager.get_feedback_audio("")
        assert audio is None


# =============================================================================
# JOB MANAGEMENT TESTS
# =============================================================================


class TestCleanupCompletedJobs:
    """Tests for cleanup_completed_jobs."""

    @pytest.mark.asyncio
    async def test_cleanup_removes_old_completed_jobs(self, kb_manager):
        """Test that old completed jobs are removed."""
        from datetime import timedelta

        # Add a completed job with old timestamp
        progress = KBPrefetchProgress(
            job_id="old_job_123",
            module_id="test-module",
            total_segments=10,
            completed=10,
            status="completed",
            completed_at=datetime.now() - timedelta(hours=2),
        )
        task = MagicMock()
        kb_manager._jobs["old_job_123"] = (task, progress)

        # Clean up with 1 hour max age
        removed = kb_manager.cleanup_completed_jobs(max_age_seconds=3600)

        assert removed == 1
        assert "old_job_123" not in kb_manager._jobs

    @pytest.mark.asyncio
    async def test_cleanup_keeps_recent_jobs(self, kb_manager):
        """Test that recent completed jobs are kept."""
        from datetime import timedelta

        # Add a recently completed job
        progress = KBPrefetchProgress(
            job_id="recent_job_123",
            module_id="test-module",
            total_segments=10,
            completed=10,
            status="completed",
            completed_at=datetime.now() - timedelta(minutes=10),
        )
        task = MagicMock()
        kb_manager._jobs["recent_job_123"] = (task, progress)

        # Clean up with 1 hour max age
        removed = kb_manager.cleanup_completed_jobs(max_age_seconds=3600)

        assert removed == 0
        assert "recent_job_123" in kb_manager._jobs

    @pytest.mark.asyncio
    async def test_cleanup_keeps_in_progress_jobs(self, kb_manager):
        """Test that in-progress jobs are not removed."""
        # Add an in-progress job
        progress = KBPrefetchProgress(
            job_id="active_job_123",
            module_id="test-module",
            total_segments=10,
            completed=5,
            status="in_progress",
        )
        task = MagicMock()
        kb_manager._jobs["active_job_123"] = (task, progress)

        # Clean up
        removed = kb_manager.cleanup_completed_jobs(max_age_seconds=0)

        assert removed == 0
        assert "active_job_123" in kb_manager._jobs


class TestGetAllJobs:
    """Tests for get_all_jobs."""

    @pytest.mark.asyncio
    async def test_get_all_jobs_empty(self, kb_manager):
        """Test getting jobs when none exist."""
        jobs = kb_manager.get_all_jobs()
        assert jobs == []

    @pytest.mark.asyncio
    async def test_get_all_jobs_returns_all(self, kb_manager):
        """Test getting all jobs."""
        # Add some jobs
        for i in range(3):
            progress = KBPrefetchProgress(
                job_id=f"job_{i}",
                module_id="test-module",
                total_segments=10,
                status="in_progress",
            )
            task = MagicMock()
            kb_manager._jobs[f"job_{i}"] = (task, progress)

        jobs = kb_manager.get_all_jobs()
        assert len(jobs) == 3


class TestCancelJob:
    """Tests for job cancellation."""

    @pytest.mark.asyncio
    async def test_cancel_nonexistent_job(self, kb_manager):
        """Test cancelling a job that doesn't exist."""
        result = await kb_manager.cancel("nonexistent")
        assert result is False

    @pytest.mark.asyncio
    async def test_cancel_existing_job(self, kb_manager):
        """Test cancelling an existing job."""
        # Add a job
        progress = KBPrefetchProgress(
            job_id="job_to_cancel",
            module_id="test-module",
            total_segments=10,
            status="in_progress",
        )
        task = MagicMock()
        kb_manager._jobs["job_to_cancel"] = (task, progress)

        result = await kb_manager.cancel("job_to_cancel")

        assert result is True
        assert progress.status == "cancelled"
        task.cancel.assert_called_once()


# =============================================================================
# FEEDBACK AUDIO GENERATION TESTS
# =============================================================================


class TestGenerateFeedbackAudio:
    """Tests for generate_feedback_audio."""

    @pytest.mark.asyncio
    async def test_generate_feedback_creates_files(self, tmp_kb_dir, mock_resource_pool):
        """Test that feedback audio files are created."""
        # Set up mock to return audio data
        mock_resource_pool.generate_with_priority = AsyncMock(
            return_value=(b"RIFF" + b"\x00" * 100, 24000, 1.0)
        )

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        await manager.generate_feedback_audio()

        feedback_dir = tmp_kb_dir / "feedback"
        assert (feedback_dir / "correct.wav").exists()
        assert (feedback_dir / "incorrect.wav").exists()

    @pytest.mark.asyncio
    async def test_generate_feedback_skips_existing(self, tmp_kb_dir, mock_resource_pool):
        """Test that existing feedback files are not regenerated."""
        # Create existing feedback files
        feedback_dir = tmp_kb_dir / "feedback"
        feedback_dir.mkdir(parents=True)
        (feedback_dir / "correct.wav").write_bytes(b"existing")
        (feedback_dir / "incorrect.wav").write_bytes(b"existing")

        mock_resource_pool.generate_with_priority = AsyncMock(
            return_value=(b"RIFF" + b"\x00" * 100, 24000, 1.0)
        )

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        await manager.generate_feedback_audio()

        # Verify files weren't overwritten
        assert (feedback_dir / "correct.wav").read_bytes() == b"existing"
        # And TTS was never called
        mock_resource_pool.generate_with_priority.assert_not_called()

    @pytest.mark.asyncio
    async def test_generate_feedback_handles_errors(self, tmp_kb_dir, mock_resource_pool):
        """Test that errors during feedback generation are handled."""
        mock_resource_pool.generate_with_priority = AsyncMock(
            side_effect=Exception("TTS error")
        )

        manager = KBAudioManager(str(tmp_kb_dir), mock_resource_pool)
        await manager.initialize()

        # Should not raise
        await manager.generate_feedback_audio()

        # Files should not exist
        feedback_dir = tmp_kb_dir / "feedback"
        assert not (feedback_dir / "correct.wav").exists()
