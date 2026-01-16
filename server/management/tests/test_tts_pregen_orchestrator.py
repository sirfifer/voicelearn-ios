"""Tests for TTS Pre-Generation Orchestrator."""

from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from tts_pregen import (
    TTSPregenJob,
    TTSJobItem,
    JobStatus,
    ItemStatus,
)
from tts_pregen.orchestrator import (
    TTSPregenOrchestrator,
    MAX_RETRIES,
    RETRY_DELAYS,
    MAX_CONSECUTIVE_FAILURES,
)


@pytest.fixture
def mock_job_manager():
    """Create a mock job manager."""
    manager = AsyncMock()
    manager.get_job = AsyncMock()
    manager.start_job = AsyncMock()
    manager.pause_job = AsyncMock()
    manager.complete_job = AsyncMock()
    manager.fail_job = AsyncMock()
    manager.get_pending_items = AsyncMock()
    manager.update_item = AsyncMock()
    manager.resolve_tts_config = AsyncMock()
    manager.ensure_output_directory = AsyncMock()
    manager.repository = AsyncMock()
    manager.repository.update_job = AsyncMock()
    return manager


@pytest.fixture
def mock_tts_pool():
    """Create a mock TTS resource pool."""
    pool = AsyncMock()
    pool.generate_with_priority = AsyncMock()
    return pool


@pytest.fixture
def orchestrator(mock_job_manager, mock_tts_pool):
    """Create orchestrator with mocks."""
    return TTSPregenOrchestrator(
        job_manager=mock_job_manager,
        tts_resource_pool=mock_tts_pool,
    )


@pytest.fixture
def sample_job():
    """Create a sample job."""
    return TTSPregenJob(
        id=uuid4(),
        name="Test Job",
        job_type="batch",
        source_type="custom",
        total_items=5,
        status=JobStatus.PENDING,
        output_format="wav",
    )


@pytest.fixture
def sample_job_item():
    """Create a sample job item."""
    return TTSJobItem(
        id=uuid4(),
        job_id=uuid4(),
        item_index=0,
        text_content="Hello world",
        text_hash="abc12345",
        status=ItemStatus.PENDING,
    )


class TestOrchestratorStartJob:
    """Tests for starting jobs."""

    @pytest.mark.asyncio
    async def test_start_job_success(self, orchestrator, mock_job_manager, sample_job):
        """Test successfully starting a job."""
        sample_job.status = JobStatus.PENDING
        mock_job_manager.get_job.return_value = sample_job
        mock_job_manager.start_job.return_value = sample_job
        mock_job_manager.resolve_tts_config.return_value = {
            "provider": "test",
            "voice_id": "voice1",
            "settings": {},
        }
        mock_job_manager.ensure_output_directory.return_value = Path("/tmp/output")
        # Return empty list to complete job immediately
        mock_job_manager.get_pending_items.return_value = []

        result = await orchestrator.start_job(sample_job.id)

        assert result is True
        mock_job_manager.get_job.assert_called()
        mock_job_manager.start_job.assert_called_with(sample_job.id)

    @pytest.mark.asyncio
    async def test_start_job_already_running(self, orchestrator, sample_job):
        """Test starting a job that's already running."""
        orchestrator._running_jobs.add(sample_job.id)

        result = await orchestrator.start_job(sample_job.id)

        assert result is False

    @pytest.mark.asyncio
    async def test_start_job_not_found(self, orchestrator, mock_job_manager):
        """Test starting a job that doesn't exist."""
        mock_job_manager.get_job.return_value = None

        result = await orchestrator.start_job(uuid4())

        assert result is False

    @pytest.mark.asyncio
    async def test_start_job_wrong_status(self, orchestrator, mock_job_manager, sample_job):
        """Test starting a job with wrong status."""
        sample_job.status = JobStatus.COMPLETED
        mock_job_manager.get_job.return_value = sample_job

        result = await orchestrator.start_job(sample_job.id)

        assert result is False

    @pytest.mark.asyncio
    async def test_start_paused_job(self, orchestrator, mock_job_manager, sample_job):
        """Test restarting a paused job."""
        sample_job.status = JobStatus.PAUSED
        mock_job_manager.get_job.return_value = sample_job
        mock_job_manager.start_job.return_value = sample_job
        mock_job_manager.resolve_tts_config.return_value = {
            "provider": "test",
            "voice_id": "voice1",
            "settings": {},
        }
        mock_job_manager.ensure_output_directory.return_value = Path("/tmp/output")
        mock_job_manager.get_pending_items.return_value = []

        result = await orchestrator.start_job(sample_job.id)

        assert result is True


class TestOrchestratorStopJob:
    """Tests for stopping jobs."""

    @pytest.mark.asyncio
    async def test_stop_running_job(self, orchestrator, sample_job):
        """Test stopping a running job."""
        orchestrator._running_jobs.add(sample_job.id)
        orchestrator._stop_flags[sample_job.id] = False

        result = await orchestrator.stop_job(sample_job.id)

        assert result is True
        assert orchestrator._stop_flags[sample_job.id] is True

    @pytest.mark.asyncio
    async def test_stop_job_not_running(self, orchestrator):
        """Test stopping a job that's not running."""
        result = await orchestrator.stop_job(uuid4())

        assert result is False


class TestOrchestratorProcessItem:
    """Tests for processing individual items.

    Note: The _process_item method has a dynamic import (from ..tts_cache.resource_pool)
    which is tested indirectly through integration tests and the _process_job tests.
    These unit tests validate the retry logic and state management aspects that don't
    require the actual TTS generation to execute.
    """

    @pytest.mark.asyncio
    async def test_process_item_updates_status_on_start(
        self, orchestrator, mock_job_manager, sample_job_item
    ):
        """Test that process_item updates item status to PROCESSING."""
        # Mock the job manager to track status changes
        item_updates = []

        async def track_update(item):
            item_updates.append(item.status)

        mock_job_manager.update_item.side_effect = track_update

        # The method will fail due to import, but we can verify it tried to update status
        await orchestrator._process_item(
            item=sample_job_item,
            provider="test",
            voice_id="voice1",
            settings={},
            output_dir=Path("/tmp/output"),
            output_format="wav",
        )

        # First update should set PROCESSING
        assert ItemStatus.PROCESSING in item_updates
        # Final update should set FAILED (due to import error in test env)
        assert sample_job_item.status == ItemStatus.FAILED

    @pytest.mark.asyncio
    async def test_process_item_increments_attempt_count(
        self, orchestrator, sample_job_item
    ):
        """Test that process_item increments attempt count."""
        initial_attempts = sample_job_item.attempt_count

        await orchestrator._process_item(
            item=sample_job_item,
            provider="test",
            voice_id="voice1",
            settings={},
            output_dir=Path("/tmp/output"),
            output_format="wav",
        )

        # Should have incremented attempts during retries
        assert sample_job_item.attempt_count > initial_attempts

    @pytest.mark.asyncio
    async def test_process_item_records_last_error(
        self, orchestrator, sample_job_item
    ):
        """Test that process_item records errors."""
        await orchestrator._process_item(
            item=sample_job_item,
            provider="test",
            voice_id="voice1",
            settings={},
            output_dir=Path("/tmp/output"),
            output_format="wav",
        )

        # Should have recorded an error message
        assert sample_job_item.last_error is not None
        assert len(sample_job_item.last_error) > 0


class TestOrchestratorSaveWav:
    """Tests for WAV file saving."""

    def test_save_wav(self, orchestrator, tmp_path):
        """Test saving WAV file."""
        output_path = tmp_path / "test.wav"
        audio_data = b"\x00\x00" * 1000  # 2000 bytes of 16-bit samples
        sample_rate = 16000

        orchestrator._save_wav(output_path, audio_data, sample_rate)

        assert output_path.exists()


class TestOrchestratorHelpers:
    """Tests for helper methods."""

    def test_is_job_running(self, orchestrator, sample_job):
        """Test checking if job is running."""
        assert orchestrator.is_job_running(sample_job.id) is False

        orchestrator._running_jobs.add(sample_job.id)
        assert orchestrator.is_job_running(sample_job.id) is True

    def test_get_running_jobs(self, orchestrator):
        """Test getting running jobs."""
        job_id1 = uuid4()
        job_id2 = uuid4()
        orchestrator._running_jobs.add(job_id1)
        orchestrator._running_jobs.add(job_id2)

        running = orchestrator.get_running_jobs()

        assert job_id1 in running
        assert job_id2 in running
        # Verify it returns a copy
        running.add(uuid4())
        assert len(orchestrator._running_jobs) == 2


class TestOrchestratorProcessJob:
    """Tests for job processing flow."""

    @pytest.mark.asyncio
    async def test_process_job_completes(
        self, orchestrator, mock_job_manager, mock_tts_pool, sample_job, sample_job_item
    ):
        """Test processing job to completion."""
        sample_job.status = JobStatus.RUNNING
        mock_job_manager.get_job.return_value = sample_job
        mock_job_manager.resolve_tts_config.return_value = {
            "provider": "test",
            "voice_id": "voice1",
            "settings": {},
        }
        mock_job_manager.ensure_output_directory.return_value = Path("/tmp/output")
        # Return one item, then empty
        mock_job_manager.get_pending_items.side_effect = [[sample_job_item], []]
        mock_tts_pool.generate_with_priority.return_value = (b"\x00" * 1000, 16000, 0.5)

        orchestrator._running_jobs.add(sample_job.id)
        orchestrator._stop_flags[sample_job.id] = False

        with patch("tts_pregen.orchestrator.os.path.getsize", return_value=1000):
            with patch("tts_pregen.orchestrator.wave.open", MagicMock()):
                await orchestrator._process_job(sample_job.id)

        mock_job_manager.complete_job.assert_called_with(sample_job.id)

    @pytest.mark.asyncio
    async def test_process_job_handles_exception(
        self, orchestrator, mock_job_manager, sample_job
    ):
        """Test process job handles exceptions."""
        mock_job_manager.get_job.side_effect = Exception("Database error")
        orchestrator._running_jobs.add(sample_job.id)
        orchestrator._stop_flags[sample_job.id] = False

        await orchestrator._process_job(sample_job.id)

        mock_job_manager.fail_job.assert_called()

    @pytest.mark.asyncio
    async def test_process_job_pauses_on_stop(
        self, orchestrator, mock_job_manager, sample_job
    ):
        """Test job pauses when stop flag is set."""
        sample_job.status = JobStatus.RUNNING
        mock_job_manager.get_job.return_value = sample_job
        mock_job_manager.resolve_tts_config.return_value = {
            "provider": "test",
            "voice_id": "voice1",
            "settings": {},
        }
        mock_job_manager.ensure_output_directory.return_value = Path("/tmp/output")
        mock_job_manager.get_pending_items.return_value = []

        orchestrator._running_jobs.add(sample_job.id)
        orchestrator._stop_flags[sample_job.id] = True

        await orchestrator._process_job(sample_job.id)

        mock_job_manager.pause_job.assert_called_with(sample_job.id)


class TestOrchestratorAutoResume:
    """Tests for auto-pause on failures."""

    @pytest.mark.asyncio
    async def test_auto_pause_on_consecutive_failures(
        self, orchestrator, mock_job_manager, mock_tts_pool, sample_job
    ):
        """Test job auto-pauses after too many consecutive failures."""
        sample_job.status = JobStatus.RUNNING
        sample_job.consecutive_failures = 0
        mock_job_manager.get_job.return_value = sample_job
        mock_job_manager.resolve_tts_config.return_value = {
            "provider": "test",
            "voice_id": "voice1",
            "settings": {},
        }
        mock_job_manager.ensure_output_directory.return_value = Path("/tmp/output")

        # Create items that will all fail
        failed_items = [
            TTSJobItem(
                id=uuid4(),
                job_id=sample_job.id,
                item_index=i,
                text_content=f"Text {i}",
                text_hash=f"hash{i}",
                status=ItemStatus.PENDING,
            )
            for i in range(MAX_CONSECUTIVE_FAILURES + 2)
        ]
        mock_job_manager.get_pending_items.return_value = failed_items
        mock_tts_pool.generate_with_priority.side_effect = Exception("Always fail")

        orchestrator._running_jobs.add(sample_job.id)
        orchestrator._stop_flags[sample_job.id] = False

        with patch("asyncio.sleep", AsyncMock()):
            await orchestrator._process_job(sample_job.id)

        # Should have auto-paused
        mock_job_manager.pause_job.assert_called_with(sample_job.id)


class TestOrchestratorConstants:
    """Tests for module constants."""

    def test_max_retries_is_positive(self):
        """Test MAX_RETRIES is a positive integer."""
        assert MAX_RETRIES > 0
        assert isinstance(MAX_RETRIES, int)

    def test_retry_delays_are_increasing(self):
        """Test RETRY_DELAYS are in increasing order."""
        for i in range(len(RETRY_DELAYS) - 1):
            assert RETRY_DELAYS[i] < RETRY_DELAYS[i + 1]

    def test_max_consecutive_failures_is_positive(self):
        """Test MAX_CONSECUTIVE_FAILURES is positive."""
        assert MAX_CONSECUTIVE_FAILURES > 0
