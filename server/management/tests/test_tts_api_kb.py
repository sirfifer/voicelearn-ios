"""
Tests for KB (Knowledge Bowl) API endpoints in TTS API.

Tests the following endpoints:
- GET /api/kb/audio/{question_id}/{segment}
- POST /api/kb/audio/batch
- POST /api/kb/prefetch
- GET /api/kb/prefetch/{job_id}
- GET /api/kb/manifest/{module_id}
- GET /api/kb/coverage/{module_id}
- GET /api/kb/feedback/{feedback_type}
"""

import pytest
from datetime import datetime
from unittest.mock import MagicMock
from aiohttp import web

import tts_api
from tts_cache.kb_audio import (
    KBManifest,
    KBCoverageStatus,
    KBPrefetchProgress,
)


# =============================================================================
# MOCK CLASSES
# =============================================================================


class MockKBAudioManager:
    """Mock KB Audio Manager for testing."""

    def __init__(self):
        self._audio_data = {}
        self._manifests = {}
        self._jobs = {}
        self._feedback_audio = {}

    async def get_audio(self, module_id, question_id, segment_type, hint_index=0):
        """Get audio from mock storage."""
        key = f"{module_id}/{question_id}/{segment_type}/{hint_index}"
        return self._audio_data.get(key)

    async def get_manifest(self, module_id):
        """Get manifest for module."""
        return self._manifests.get(module_id)

    def get_coverage_status(self, module_id, module_content):
        """Get coverage status."""
        return KBCoverageStatus(
            module_id=module_id,
            total_questions=10,
            covered_questions=8,
            total_segments=40,
            covered_segments=32,
            missing_segments=8,
            total_size_bytes=100000,
            is_complete=False,
        )

    async def prefetch_module(self, module_id, module_content, **kwargs):
        """Start prefetch job."""
        job_id = "kb_prefetch_test123"
        progress = KBPrefetchProgress(
            job_id=job_id,
            module_id=module_id,
            total_segments=40,
            status="in_progress",
        )
        self._jobs[job_id] = progress
        return job_id

    def get_progress(self, job_id):
        """Get job progress."""
        progress = self._jobs.get(job_id)
        if progress:
            return progress.to_dict()
        return None

    async def get_feedback_audio(self, feedback_type):
        """Get feedback audio."""
        return self._feedback_audio.get(feedback_type)

    def _estimate_duration(self, size_bytes, sample_rate=24000):
        """Estimate audio duration."""
        data_bytes = max(0, size_bytes - 44)
        samples = data_bytes // 2
        return samples / sample_rate

    def extract_segments(self, module_content):
        """Extract segments from module content."""
        return [{"id": "seg-1"}, {"id": "seg-2"}]

    def set_audio(self, module_id, question_id, segment_type, audio_data, hint_index=0):
        """Helper to set audio in mock storage."""
        key = f"{module_id}/{question_id}/{segment_type}/{hint_index}"
        self._audio_data[key] = audio_data

    def set_manifest(self, module_id, manifest):
        """Helper to set manifest."""
        self._manifests[module_id] = manifest

    def set_feedback(self, feedback_type, audio_data):
        """Helper to set feedback audio."""
        self._feedback_audio[feedback_type] = audio_data


# =============================================================================
# FIXTURES
# =============================================================================


@pytest.fixture
def mock_kb_audio_manager():
    """Create mock KB audio manager."""
    return MockKBAudioManager()


@pytest.fixture
def mock_app(mock_kb_audio_manager):
    """Create a mock aiohttp application with KB audio manager."""
    app = web.Application()
    app["kb_audio_manager"] = mock_kb_audio_manager
    return app


@pytest.fixture
def mock_request(mock_app):
    """Create a factory for mock requests."""
    def _make_request(method="GET", json_data=None, query=None, match_info=None):
        request = MagicMock(spec=web.Request)
        request.app = mock_app
        request.method = method
        request.query = query or {}
        request.match_info = match_info or {}

        if json_data is not None:
            async def mock_json():
                return json_data
            request.json = mock_json
        else:
            async def mock_json():
                raise ValueError("No JSON")
            request.json = mock_json

        return request
    return _make_request


@pytest.fixture
def sample_audio_data():
    """Sample WAV audio data."""
    return b"RIFF" + b"\x00" * 100


# =============================================================================
# TEST: handle_kb_audio_get
# =============================================================================


class TestHandleKBAudioGet:
    """Tests for GET /api/kb/audio/{question_id}/{segment}"""

    @pytest.mark.asyncio
    async def test_get_audio_success(self, mock_request, mock_kb_audio_manager, sample_audio_data):
        """Test successful audio retrieval."""
        mock_kb_audio_manager.set_audio(
            "knowledge-bowl", "sci-001", "question", sample_audio_data
        )

        request = mock_request(
            match_info={"question_id": "sci-001", "segment": "question"},
            query={}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 200
        assert response.content_type == "audio/wav"
        assert response.headers.get("X-KB-Cache-Status") == "hit"

    @pytest.mark.asyncio
    async def test_get_audio_not_found(self, mock_request):
        """Test 404 when audio not found."""
        request = mock_request(
            match_info={"question_id": "nonexistent", "segment": "question"},
            query={}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 404

    @pytest.mark.asyncio
    async def test_get_audio_invalid_segment_type(self, mock_request):
        """Test 400 for invalid segment type."""
        request = mock_request(
            match_info={"question_id": "sci-001", "segment": "invalid_segment"},
            query={}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 400

    @pytest.mark.asyncio
    async def test_get_audio_with_hint_index(self, mock_request, mock_kb_audio_manager, sample_audio_data):
        """Test audio retrieval with hint index."""
        mock_kb_audio_manager.set_audio(
            "knowledge-bowl", "sci-001", "hint", sample_audio_data, hint_index=1
        )

        request = mock_request(
            match_info={"question_id": "sci-001", "segment": "hint"},
            query={"hint_index": "1"}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 200

    @pytest.mark.asyncio
    async def test_get_audio_invalid_hint_index(self, mock_request):
        """Test 400 for invalid hint index."""
        request = mock_request(
            match_info={"question_id": "sci-001", "segment": "hint"},
            query={"hint_index": "abc"}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 400

    @pytest.mark.asyncio
    async def test_get_audio_negative_hint_index(self, mock_request):
        """Test 400 for negative hint index."""
        request = mock_request(
            match_info={"question_id": "sci-001", "segment": "hint"},
            query={"hint_index": "-1"}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 400

    @pytest.mark.asyncio
    async def test_get_audio_invalid_module_id(self, mock_request):
        """Test 400 for invalid module_id (path traversal)."""
        request = mock_request(
            match_info={"question_id": "sci-001", "segment": "question"},
            query={"module_id": "../etc"}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 400

    @pytest.mark.asyncio
    async def test_get_audio_custom_module_id(self, mock_request, mock_kb_audio_manager, sample_audio_data):
        """Test audio retrieval with custom module_id."""
        mock_kb_audio_manager.set_audio(
            "custom-module", "q-001", "question", sample_audio_data
        )

        request = mock_request(
            match_info={"question_id": "q-001", "segment": "question"},
            query={"module_id": "custom-module"}
        )
        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 200

# =============================================================================
# TEST: handle_kb_prefetch_status
# =============================================================================


class TestHandleKBPrefetchStatus:
    """Tests for GET /api/kb/prefetch/{job_id}"""

    @pytest.mark.asyncio
    async def test_get_status_success(self, mock_request, mock_kb_audio_manager):
        """Test successful status retrieval."""
        progress = KBPrefetchProgress(
            job_id="job_test123",
            module_id="knowledge-bowl",
            total_segments=40,
            completed=20,
            status="in_progress",
        )
        mock_kb_audio_manager._jobs["job_test123"] = progress

        request = mock_request(match_info={"job_id": "job_test123"})
        response = await tts_api.handle_kb_prefetch_status(request)

        assert response.status == 200

    @pytest.mark.asyncio
    async def test_get_status_not_found(self, mock_request):
        """Test 404 when job not found."""
        request = mock_request(match_info={"job_id": "nonexistent_job"})
        response = await tts_api.handle_kb_prefetch_status(request)

        assert response.status == 404


# =============================================================================
# TEST: handle_kb_manifest
# =============================================================================


class TestHandleKBManifest:
    """Tests for GET /api/kb/manifest/{module_id}"""

    @pytest.mark.asyncio
    async def test_get_manifest_success(self, mock_request, mock_kb_audio_manager):
        """Test successful manifest retrieval."""
        manifest = KBManifest(
            module_id="knowledge-bowl",
            voice_id="nova",
            provider="vibevoice",
            generated_at=datetime.now(),
            total_questions=10,
            total_segments=40,
        )
        mock_kb_audio_manager.set_manifest("knowledge-bowl", manifest)

        request = mock_request(match_info={"module_id": "knowledge-bowl"})
        response = await tts_api.handle_kb_manifest(request)

        assert response.status == 200

    @pytest.mark.asyncio
    async def test_get_manifest_not_found(self, mock_request):
        """Test 404 when manifest not found."""
        request = mock_request(match_info={"module_id": "nonexistent-module"})
        response = await tts_api.handle_kb_manifest(request)

        assert response.status == 404

    @pytest.mark.asyncio
    async def test_get_manifest_invalid_module_id(self, mock_request):
        """Test 400 for invalid module_id."""
        request = mock_request(match_info={"module_id": "../etc"})
        response = await tts_api.handle_kb_manifest(request)

        assert response.status == 400


# =============================================================================
# TEST: handle_kb_feedback_audio
# =============================================================================


class TestHandleKBFeedbackAudio:
    """Tests for GET /api/kb/feedback/{feedback_type}"""

    @pytest.mark.asyncio
    async def test_get_feedback_correct(self, mock_request, mock_kb_audio_manager, sample_audio_data):
        """Test getting correct feedback audio."""
        mock_kb_audio_manager.set_feedback("correct", sample_audio_data)

        request = mock_request(match_info={"feedback_type": "correct"})
        response = await tts_api.handle_kb_feedback_audio(request)

        assert response.status == 200
        assert response.content_type == "audio/wav"

    @pytest.mark.asyncio
    async def test_get_feedback_incorrect(self, mock_request, mock_kb_audio_manager, sample_audio_data):
        """Test getting incorrect feedback audio."""
        mock_kb_audio_manager.set_feedback("incorrect", sample_audio_data)

        request = mock_request(match_info={"feedback_type": "incorrect"})
        response = await tts_api.handle_kb_feedback_audio(request)

        assert response.status == 200

    @pytest.mark.asyncio
    async def test_get_feedback_not_found(self, mock_request):
        """Test 404 when feedback audio not found."""
        request = mock_request(match_info={"feedback_type": "correct"})
        response = await tts_api.handle_kb_feedback_audio(request)

        assert response.status == 404

    @pytest.mark.asyncio
    async def test_get_feedback_invalid_type(self, mock_request):
        """Test 400 for invalid feedback type."""
        request = mock_request(match_info={"feedback_type": "invalid_type"})
        response = await tts_api.handle_kb_feedback_audio(request)

        assert response.status == 400


# =============================================================================
# TEST: handle_kb_coverage
# =============================================================================


class TestHandleKBCoverage:
    """Tests for GET /api/kb/coverage/{module_id}"""

    @pytest.mark.asyncio
    async def test_get_coverage_invalid_module_id(self, mock_request):
        """Test 400 for invalid module_id."""
        request = mock_request(match_info={"module_id": "../etc"})
        response = await tts_api.handle_kb_coverage(request)

        assert response.status == 400


# =============================================================================
# TEST: handle_kb_prefetch
# =============================================================================


class TestHandleKBPrefetch:
    """Tests for POST /api/kb/prefetch"""

    @pytest.mark.asyncio
    async def test_prefetch_invalid_module_id(self, mock_request):
        """Test 400 for invalid module_id."""
        request = mock_request(
            method="POST",
            json_data={"module_id": "../etc"}
        )
        response = await tts_api.handle_kb_prefetch(request)

        assert response.status == 400


# =============================================================================
# TEST: handle_kb_audio_batch
# =============================================================================


class TestHandleKBAudioBatch:
    """Tests for POST /api/kb/audio/batch"""

    @pytest.mark.asyncio
    async def test_batch_success(self, mock_request, mock_kb_audio_manager):
        """Test successful batch metadata retrieval."""
        manifest = KBManifest(
            module_id="knowledge-bowl",
            voice_id="nova",
            provider="vibevoice",
            generated_at=datetime.now(),
        )
        mock_kb_audio_manager.set_manifest("knowledge-bowl", manifest)

        request = mock_request(
            method="POST",
            json_data={
                "module_id": "knowledge-bowl",
                "question_ids": ["sci-001", "sci-002"],
            }
        )
        response = await tts_api.handle_kb_audio_batch(request)

        assert response.status == 200

    @pytest.mark.asyncio
    async def test_batch_invalid_module_id(self, mock_request):
        """Test 400 for invalid module_id in batch request."""
        request = mock_request(
            method="POST",
            json_data={
                "module_id": "../etc",
                "question_ids": ["sci-001"],
            }
        )
        response = await tts_api.handle_kb_audio_batch(request)

        assert response.status == 400

    @pytest.mark.asyncio
    async def test_batch_missing_question_ids(self, mock_request):
        """Test 400 when question_ids missing."""
        request = mock_request(
            method="POST",
            json_data={"module_id": "knowledge-bowl"}
        )
        response = await tts_api.handle_kb_audio_batch(request)

        assert response.status == 400


# =============================================================================
# TEST: No KB Manager Initialized
# =============================================================================


class TestNoKBManager:
    """Tests for when KB audio manager is not initialized."""

    @pytest.mark.asyncio
    async def test_get_audio_no_manager(self):
        """Test 503 when KB manager not initialized."""
        app = web.Application()  # No kb_audio_manager
        request = MagicMock(spec=web.Request)
        request.app = app
        request.match_info = {"question_id": "sci-001", "segment": "question"}
        request.query = {}

        response = await tts_api.handle_kb_audio_get(request)

        assert response.status == 503

    @pytest.mark.asyncio
    async def test_get_feedback_no_manager(self):
        """Test 503 when KB manager not initialized for feedback."""
        app = web.Application()  # No kb_audio_manager
        request = MagicMock(spec=web.Request)
        request.app = app
        request.match_info = {"feedback_type": "correct"}

        response = await tts_api.handle_kb_feedback_audio(request)

        assert response.status == 503

    @pytest.mark.asyncio
    async def test_get_manifest_no_manager(self):
        """Test 503 when KB manager not initialized for manifest."""
        app = web.Application()  # No kb_audio_manager
        request = MagicMock(spec=web.Request)
        request.app = app
        request.match_info = {"module_id": "knowledge-bowl"}

        response = await tts_api.handle_kb_manifest(request)

        assert response.status == 503

    @pytest.mark.asyncio
    async def test_prefetch_status_no_manager(self):
        """Test 503 when KB manager not initialized for prefetch status."""
        app = web.Application()  # No kb_audio_manager
        request = MagicMock(spec=web.Request)
        request.app = app
        request.match_info = {"job_id": "job_123"}

        response = await tts_api.handle_kb_prefetch_status(request)

        assert response.status == 503
