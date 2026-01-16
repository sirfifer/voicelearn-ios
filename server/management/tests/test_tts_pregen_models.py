"""
Tests for TTS Pre-Generation models.
"""
import pytest
from datetime import datetime
from uuid import UUID, uuid4
import hashlib

from tts_pregen.models import (
    JobStatus,
    ItemStatus,
    SessionStatus,
    VariantStatus,
    TTSProfileSettings,
    TTSProfile,
    TTSModuleProfile,
    TTSPregenJob,
    TTSJobItem,
    TTSComparisonSession,
    TTSComparisonVariant,
    TTSComparisonRating,
)


class TestEnums:
    """Tests for status enums."""

    def test_job_status_values(self):
        """Test JobStatus enum values."""
        assert JobStatus.PENDING.value == "pending"
        assert JobStatus.RUNNING.value == "running"
        assert JobStatus.PAUSED.value == "paused"
        assert JobStatus.COMPLETED.value == "completed"
        assert JobStatus.FAILED.value == "failed"
        assert JobStatus.CANCELLED.value == "cancelled"

    def test_item_status_values(self):
        """Test ItemStatus enum values."""
        assert ItemStatus.PENDING.value == "pending"
        assert ItemStatus.PROCESSING.value == "processing"
        assert ItemStatus.COMPLETED.value == "completed"
        assert ItemStatus.FAILED.value == "failed"
        assert ItemStatus.SKIPPED.value == "skipped"

    def test_session_status_values(self):
        """Test SessionStatus enum values."""
        assert SessionStatus.DRAFT.value == "draft"
        assert SessionStatus.GENERATING.value == "generating"
        assert SessionStatus.READY.value == "ready"
        assert SessionStatus.ARCHIVED.value == "archived"

    def test_variant_status_values(self):
        """Test VariantStatus enum values."""
        assert VariantStatus.PENDING.value == "pending"
        assert VariantStatus.GENERATING.value == "generating"
        assert VariantStatus.READY.value == "ready"
        assert VariantStatus.FAILED.value == "failed"


class TestTTSProfileSettings:
    """Tests for TTSProfileSettings dataclass."""

    def test_default_values(self):
        """Test default settings values."""
        settings = TTSProfileSettings()
        assert settings.speed == 1.0
        assert settings.exaggeration is None
        assert settings.cfg_weight is None
        assert settings.language is None
        assert settings.extra == {}

    def test_custom_values(self):
        """Test settings with custom values."""
        settings = TTSProfileSettings(
            speed=1.5,
            exaggeration=0.7,
            cfg_weight=0.5,
            language="en",
            extra={"custom_key": "value"},
        )
        assert settings.speed == 1.5
        assert settings.exaggeration == 0.7
        assert settings.cfg_weight == 0.5
        assert settings.language == "en"
        assert settings.extra == {"custom_key": "value"}

    def test_to_dict_minimal(self):
        """Test to_dict with minimal settings."""
        settings = TTSProfileSettings()
        d = settings.to_dict()
        assert d == {"speed": 1.0}

    def test_to_dict_full(self):
        """Test to_dict with all settings."""
        settings = TTSProfileSettings(
            speed=1.2,
            exaggeration=0.8,
            cfg_weight=0.6,
            language="es",
            extra={"foo": "bar"},
        )
        d = settings.to_dict()
        assert d == {
            "speed": 1.2,
            "exaggeration": 0.8,
            "cfg_weight": 0.6,
            "language": "es",
            "extra": {"foo": "bar"},
        }

    def test_from_dict_minimal(self):
        """Test from_dict with minimal data."""
        settings = TTSProfileSettings.from_dict({})
        assert settings.speed == 1.0
        assert settings.exaggeration is None

    def test_from_dict_full(self):
        """Test from_dict with full data."""
        d = {
            "speed": 0.9,
            "exaggeration": 0.5,
            "cfg_weight": 0.3,
            "language": "fr",
            "extra": {"key": "value"},
        }
        settings = TTSProfileSettings.from_dict(d)
        assert settings.speed == 0.9
        assert settings.exaggeration == 0.5
        assert settings.cfg_weight == 0.3
        assert settings.language == "fr"
        assert settings.extra == {"key": "value"}

    def test_roundtrip(self):
        """Test to_dict and from_dict roundtrip."""
        original = TTSProfileSettings(
            speed=1.3,
            exaggeration=0.9,
            cfg_weight=0.4,
        )
        d = original.to_dict()
        restored = TTSProfileSettings.from_dict(d)
        assert restored.speed == original.speed
        assert restored.exaggeration == original.exaggeration
        assert restored.cfg_weight == original.cfg_weight


class TestTTSProfile:
    """Tests for TTSProfile dataclass."""

    def test_create_factory(self):
        """Test profile creation with factory method."""
        profile = TTSProfile.create(
            name="Test Profile",
            provider="chatterbox",
            voice_id="default",
        )
        assert isinstance(profile.id, UUID)
        assert profile.name == "Test Profile"
        assert profile.provider == "chatterbox"
        assert profile.voice_id == "default"
        assert profile.is_active is True
        assert profile.is_default is False
        assert profile.tags == []

    def test_create_with_settings(self):
        """Test profile creation with custom settings."""
        settings = TTSProfileSettings(speed=1.2, exaggeration=0.7)
        profile = TTSProfile.create(
            name="Custom Profile",
            provider="chatterbox",
            voice_id="expressive",
            settings=settings,
            description="A custom profile",
            tags=["tutor", "expressive"],
            use_case="tutoring",
        )
        assert profile.settings.speed == 1.2
        assert profile.settings.exaggeration == 0.7
        assert profile.description == "A custom profile"
        assert "tutor" in profile.tags
        assert profile.use_case == "tutoring"

    def test_to_dict(self):
        """Test profile to_dict."""
        profile = TTSProfile.create(
            name="Dict Test",
            provider="vibevoice",
            voice_id="nova",
        )
        d = profile.to_dict()

        assert d["name"] == "Dict Test"
        assert d["provider"] == "vibevoice"
        assert d["voice_id"] == "nova"
        assert d["id"] == str(profile.id)
        assert isinstance(d["settings"], dict)
        assert isinstance(d["created_at"], str)

    def test_from_dict(self):
        """Test profile from_dict."""
        d = {
            "id": str(uuid4()),
            "name": "From Dict Profile",
            "provider": "piper",
            "voice_id": "amy",
            "settings": {"speed": 1.1},
            "tags": ["narrator"],
            "is_active": True,
            "is_default": False,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
        }
        profile = TTSProfile.from_dict(d)

        assert profile.name == "From Dict Profile"
        assert profile.provider == "piper"
        assert profile.voice_id == "amy"
        assert profile.settings.speed == 1.1
        assert "narrator" in profile.tags

    def test_roundtrip(self):
        """Test profile roundtrip serialization."""
        original = TTSProfile.create(
            name="Roundtrip Test",
            provider="chatterbox",
            voice_id="test",
            settings=TTSProfileSettings(speed=1.5, exaggeration=0.8),
            description="Test description",
            tags=["test", "roundtrip"],
            use_case="testing",
        )
        d = original.to_dict()
        restored = TTSProfile.from_dict(d)

        assert restored.id == original.id
        assert restored.name == original.name
        assert restored.provider == original.provider
        assert restored.settings.speed == original.settings.speed
        assert restored.tags == original.tags


class TestTTSModuleProfile:
    """Tests for TTSModuleProfile dataclass."""

    def test_create(self):
        """Test module profile creation."""
        profile_id = uuid4()
        mp = TTSModuleProfile(
            id=uuid4(),
            module_id="knowledge-bowl",
            profile_id=profile_id,
            context="questions",
            priority=10,
        )
        assert mp.module_id == "knowledge-bowl"
        assert mp.profile_id == profile_id
        assert mp.context == "questions"
        assert mp.priority == 10

    def test_to_dict(self):
        """Test module profile to_dict."""
        mp = TTSModuleProfile(
            id=uuid4(),
            module_id="test-module",
            profile_id=uuid4(),
            priority=5,
        )
        d = mp.to_dict()

        assert d["module_id"] == "test-module"
        assert d["priority"] == 5
        assert d["context"] is None


class TestTTSPregenJob:
    """Tests for TTSPregenJob dataclass."""

    def test_create_factory(self):
        """Test job creation with factory method."""
        job = TTSPregenJob.create(
            name="Test Job",
            source_type="knowledge-bowl",
            output_dir="/data/tts-pregenerated/test",
        )
        assert isinstance(job.id, UUID)
        assert job.name == "Test Job"
        assert job.source_type == "knowledge-bowl"
        assert job.status == JobStatus.PENDING
        assert job.job_type == "batch"
        assert job.total_items == 0

    def test_create_with_profile(self):
        """Test job creation with profile."""
        profile_id = uuid4()
        job = TTSPregenJob.create(
            name="Profile Job",
            source_type="curriculum",
            output_dir="/output",
            profile_id=profile_id,
            source_id="curriculum-123",
        )
        assert job.profile_id == profile_id
        assert job.source_id == "curriculum-123"

    def test_create_with_inline_config(self):
        """Test job creation with inline TTS config."""
        config = {"provider": "chatterbox", "voice_id": "default"}
        job = TTSPregenJob.create(
            name="Config Job",
            source_type="custom",
            output_dir="/output",
            tts_config=config,
        )
        assert job.tts_config == config
        assert job.profile_id is None

    def test_percent_complete(self):
        """Test percent_complete property."""
        job = TTSPregenJob.create(
            name="Progress Test",
            source_type="test",
            output_dir="/output",
        )
        job.total_items = 100
        job.completed_items = 25
        assert job.percent_complete == 25.0

        job.completed_items = 0
        assert job.percent_complete == 0.0

        job.total_items = 0
        assert job.percent_complete == 0.0

    def test_pending_items(self):
        """Test pending_items property."""
        job = TTSPregenJob.create(
            name="Pending Test",
            source_type="test",
            output_dir="/output",
        )
        job.total_items = 100
        job.completed_items = 30
        job.failed_items = 5
        assert job.pending_items == 65

    def test_is_resumable(self):
        """Test is_resumable property."""
        job = TTSPregenJob.create(
            name="Resume Test",
            source_type="test",
            output_dir="/output",
        )
        assert not job.is_resumable  # PENDING is not resumable

        job.status = JobStatus.RUNNING
        assert not job.is_resumable

        job.status = JobStatus.PAUSED
        assert job.is_resumable

        job.status = JobStatus.FAILED
        assert job.is_resumable

        job.status = JobStatus.COMPLETED
        assert not job.is_resumable

    def test_to_dict_progress(self):
        """Test to_dict includes progress info."""
        job = TTSPregenJob.create(
            name="Dict Test",
            source_type="test",
            output_dir="/output",
        )
        job.total_items = 50
        job.completed_items = 20
        job.failed_items = 5
        job.current_item_index = 25
        job.current_item_text = "Current text"

        d = job.to_dict()
        progress = d["progress"]

        assert progress["total"] == 50
        assert progress["completed"] == 20
        assert progress["failed"] == 5
        assert progress["pending"] == 25
        assert progress["percent_complete"] == 40.0
        assert progress["current_index"] == 25
        assert progress["current_text"] == "Current text"

    def test_roundtrip(self):
        """Test job roundtrip serialization."""
        profile_id = uuid4()
        original = TTSPregenJob.create(
            name="Roundtrip Test",
            source_type="knowledge-bowl",
            output_dir="/output/test",
            profile_id=profile_id,
            normalize_volume=True,
        )
        original.total_items = 100
        original.completed_items = 50
        original.status = JobStatus.RUNNING

        d = original.to_dict()
        restored = TTSPregenJob.from_dict(d)

        assert restored.id == original.id
        assert restored.name == original.name
        assert restored.profile_id == original.profile_id
        assert restored.status == original.status
        assert restored.total_items == original.total_items
        assert restored.completed_items == original.completed_items


class TestTTSJobItem:
    """Tests for TTSJobItem dataclass."""

    def test_create_factory(self):
        """Test item creation with factory method."""
        job_id = uuid4()
        item = TTSJobItem.create(
            job_id=job_id,
            item_index=0,
            text_content="Hello, world!",
            source_ref="question_1",
        )
        assert isinstance(item.id, UUID)
        assert item.job_id == job_id
        assert item.item_index == 0
        assert item.text_content == "Hello, world!"
        assert item.source_ref == "question_1"
        assert item.status == ItemStatus.PENDING
        assert item.attempt_count == 0

    def test_hash_text(self):
        """Test text hashing."""
        text = "Test content"
        hash_result = TTSJobItem.hash_text(text)

        expected = hashlib.sha256(text.encode()).hexdigest()
        assert hash_result == expected

    def test_auto_hash(self):
        """Test automatic hash generation on create."""
        item = TTSJobItem.create(
            job_id=uuid4(),
            item_index=0,
            text_content="Auto hash test",
        )
        expected_hash = TTSJobItem.hash_text("Auto hash test")
        assert item.text_hash == expected_hash

    def test_to_dict(self):
        """Test item to_dict."""
        item = TTSJobItem.create(
            job_id=uuid4(),
            item_index=5,
            text_content="Dict test",
        )
        item.status = ItemStatus.COMPLETED
        item.output_file = "/output/test.wav"
        item.duration_seconds = 2.5

        d = item.to_dict()
        assert d["item_index"] == 5
        assert d["status"] == "completed"
        assert d["output_file"] == "/output/test.wav"
        assert d["duration_seconds"] == 2.5


class TestTTSComparisonSession:
    """Tests for TTSComparisonSession dataclass."""

    def test_create_factory(self):
        """Test session creation with factory method."""
        samples = [
            {"text": "Sample 1"},
            {"text": "Sample 2"},
        ]
        configs = [
            {"name": "Config A", "provider": "chatterbox", "voice_id": "default", "settings": {}},
            {"name": "Config B", "provider": "vibevoice", "voice_id": "nova", "settings": {}},
        ]
        session = TTSComparisonSession.create(
            name="Test Session",
            samples=samples,
            configurations=configs,
            description="A test comparison session",
        )

        assert isinstance(session.id, UUID)
        assert session.name == "Test Session"
        assert session.status == SessionStatus.DRAFT
        assert session.description == "A test comparison session"

    def test_sample_count(self):
        """Test sample_count property."""
        session = TTSComparisonSession.create(
            name="Count Test",
            samples=[{"text": "1"}, {"text": "2"}, {"text": "3"}],
            configurations=[],
        )
        assert session.sample_count == 3

    def test_config_count(self):
        """Test config_count property."""
        session = TTSComparisonSession.create(
            name="Config Count Test",
            samples=[],
            configurations=[
                {"name": "A", "provider": "test", "voice_id": "1", "settings": {}},
                {"name": "B", "provider": "test", "voice_id": "2", "settings": {}},
            ],
        )
        assert session.config_count == 2

    def test_total_variants(self):
        """Test total_variants property."""
        session = TTSComparisonSession.create(
            name="Variants Test",
            samples=[{"text": "1"}, {"text": "2"}],
            configurations=[
                {"name": "A", "provider": "test", "voice_id": "1", "settings": {}},
                {"name": "B", "provider": "test", "voice_id": "2", "settings": {}},
                {"name": "C", "provider": "test", "voice_id": "3", "settings": {}},
            ],
        )
        # 2 samples x 3 configs = 6 variants
        assert session.total_variants == 6

    def test_to_dict(self):
        """Test session to_dict includes computed properties."""
        session = TTSComparisonSession.create(
            name="Dict Test",
            samples=[{"text": "1"}],
            configurations=[
                {"name": "A", "provider": "test", "voice_id": "1", "settings": {}},
            ],
        )
        d = session.to_dict()

        assert d["name"] == "Dict Test"
        assert d["sample_count"] == 1
        assert d["config_count"] == 1
        assert d["total_variants"] == 1


class TestTTSComparisonVariant:
    """Tests for TTSComparisonVariant dataclass."""

    def test_create_factory(self):
        """Test variant creation with factory method."""
        session_id = uuid4()
        config = {"provider": "chatterbox", "voice_id": "default"}
        variant = TTSComparisonVariant.create(
            session_id=session_id,
            sample_index=0,
            config_index=1,
            text_content="Test text",
            tts_config=config,
        )

        assert isinstance(variant.id, UUID)
        assert variant.session_id == session_id
        assert variant.sample_index == 0
        assert variant.config_index == 1
        assert variant.text_content == "Test text"
        assert variant.tts_config == config
        assert variant.status == VariantStatus.PENDING

    def test_to_dict(self):
        """Test variant to_dict."""
        variant = TTSComparisonVariant.create(
            session_id=uuid4(),
            sample_index=1,
            config_index=2,
            text_content="Dict test",
            tts_config={"provider": "test"},
        )
        variant.status = VariantStatus.READY
        variant.output_file = "/output/variant.wav"
        variant.duration_seconds = 3.5

        d = variant.to_dict()
        assert d["sample_index"] == 1
        assert d["config_index"] == 2
        assert d["status"] == "ready"
        assert d["output_file"] == "/output/variant.wav"


class TestTTSComparisonRating:
    """Tests for TTSComparisonRating dataclass."""

    def test_create_factory(self):
        """Test rating creation with factory method."""
        variant_id = uuid4()
        rating = TTSComparisonRating.create(
            variant_id=variant_id,
            rating=4,
            notes="Good quality",
        )

        assert isinstance(rating.id, UUID)
        assert rating.variant_id == variant_id
        assert rating.rating == 4
        assert rating.notes == "Good quality"

    def test_create_without_rating(self):
        """Test rating creation without initial rating."""
        variant_id = uuid4()
        rating = TTSComparisonRating.create(variant_id=variant_id)

        assert rating.rating is None
        assert rating.notes is None

    def test_to_dict(self):
        """Test rating to_dict."""
        rating = TTSComparisonRating.create(
            variant_id=uuid4(),
            rating=5,
            notes="Excellent!",
        )
        d = rating.to_dict()

        assert d["rating"] == 5
        assert d["notes"] == "Excellent!"
        assert isinstance(d["rated_at"], str)
