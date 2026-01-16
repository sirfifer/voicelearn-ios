# Tests for TTS Profile Manager
# High-level service tests with mocked repository

import pytest
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4

from tts_pregen.models import (
    TTSProfile,
    TTSProfileSettings,
    TTSModuleProfile,
    TTSComparisonVariant,
    TTSComparisonSession,
    SessionStatus,
    VariantStatus,
)
from tts_pregen.profile_manager import TTSProfileManager, DEFAULT_SAMPLE_TEXT


# =============================================================================
# Fixtures
# =============================================================================


@pytest.fixture
def mock_pool():
    """Create a mock asyncpg pool."""
    return AsyncMock()


@pytest.fixture
def mock_tts_pool():
    """Create a mock TTS resource pool."""
    pool = AsyncMock()
    pool.generate_with_priority = AsyncMock(return_value=(b"audio_data", 22050, 2.5))
    return pool


@pytest.fixture
def manager(mock_pool):
    """Create a profile manager without TTS pool."""
    with patch("tts_pregen.profile_manager.PROFILE_SAMPLES_DIR", Path("/tmp/samples")):
        with patch.object(Path, "mkdir"):
            return TTSProfileManager(mock_pool, tts_resource_pool=None)


@pytest.fixture
def manager_with_tts(mock_pool, mock_tts_pool):
    """Create a profile manager with TTS pool."""
    with patch("tts_pregen.profile_manager.PROFILE_SAMPLES_DIR", Path("/tmp/samples")):
        with patch.object(Path, "mkdir"):
            return TTSProfileManager(mock_pool, tts_resource_pool=mock_tts_pool)


@pytest.fixture
def sample_profile():
    """Create a sample profile."""
    return TTSProfile.create(
        name="Test Profile",
        provider="chatterbox",
        voice_id="nova",
        settings=TTSProfileSettings(speed=1.0, exaggeration=0.5, cfg_weight=0.5),
        description="A test profile",
        tags=["test"],
        use_case="testing",
    )


@pytest.fixture
def sample_variant():
    """Create a sample comparison variant."""
    return TTSComparisonVariant.create(
        session_id=uuid4(),
        sample_index=0,
        config_index=0,
        text_content="Test text",
        tts_config={
            "provider": "chatterbox",
            "voice_id": "nova",
            "speed": 1.1,
            "exaggeration": 0.7,
        },
    )


# =============================================================================
# Profile CRUD Tests
# =============================================================================


class TestCreateProfile:
    """Tests for profile creation."""

    @pytest.mark.asyncio
    async def test_create_profile_success(self, manager, sample_profile):
        """Test successful profile creation."""
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(return_value=sample_profile)

        result = await manager.create_profile(
            name="New Profile",
            provider="chatterbox",
            voice_id="nova",
            settings={"speed": 1.0},
        )

        assert result is not None
        manager.repo.create_profile.assert_called_once()

    @pytest.mark.asyncio
    async def test_create_profile_duplicate_name(self, manager, sample_profile):
        """Test creating profile with duplicate name fails."""
        manager.repo.get_profile_by_name = AsyncMock(return_value=sample_profile)

        with pytest.raises(ValueError, match="already exists"):
            await manager.create_profile(
                name="Test Profile",
                provider="chatterbox",
                voice_id="nova",
            )

    @pytest.mark.asyncio
    async def test_create_profile_invalid_provider(self, manager):
        """Test creating profile with invalid provider fails."""
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)

        with pytest.raises(ValueError, match="Invalid provider"):
            await manager.create_profile(
                name="New Profile",
                provider="invalid_provider",
                voice_id="nova",
            )

    @pytest.mark.asyncio
    async def test_create_profile_valid_providers(self, manager, sample_profile):
        """Test creating profile with all valid providers."""
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(return_value=sample_profile)

        for provider in ["chatterbox", "vibevoice", "piper"]:
            await manager.create_profile(
                name=f"Profile {provider}",
                provider=provider,
                voice_id="default",
            )

    @pytest.mark.asyncio
    async def test_create_profile_sets_default(self, manager, sample_profile):
        """Test creating profile as default."""
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(return_value=sample_profile)
        manager.repo.set_default_profile = AsyncMock()

        await manager.create_profile(
            name="New Default",
            provider="chatterbox",
            voice_id="nova",
            is_default=True,
        )

        manager.repo.set_default_profile.assert_called_once()

    @pytest.mark.asyncio
    async def test_create_profile_with_sample_generation(self, manager_with_tts, sample_profile):
        """Test profile creation triggers sample generation."""
        manager_with_tts.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager_with_tts.repo.create_profile = AsyncMock(return_value=sample_profile)
        manager_with_tts.repo.update_profile = AsyncMock(return_value=sample_profile)

        with patch("builtins.open", MagicMock()):
            await manager_with_tts.create_profile(
                name="New Profile",
                provider="chatterbox",
                voice_id="nova",
                generate_sample=True,
            )

        manager_with_tts.tts_pool.generate_with_priority.assert_called_once()

    @pytest.mark.asyncio
    async def test_create_profile_sample_generation_failure_continues(self, manager_with_tts, sample_profile):
        """Test profile creation continues if sample generation fails."""
        manager_with_tts.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager_with_tts.repo.create_profile = AsyncMock(return_value=sample_profile)
        manager_with_tts.tts_pool.generate_with_priority = AsyncMock(side_effect=Exception("TTS Error"))

        # Should not raise, just log warning
        result = await manager_with_tts.create_profile(
            name="New Profile",
            provider="chatterbox",
            voice_id="nova",
            generate_sample=True,
        )

        assert result is not None


class TestGetProfile:
    """Tests for profile retrieval."""

    @pytest.mark.asyncio
    async def test_get_profile_by_id(self, manager, sample_profile):
        """Test getting profile by ID."""
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)

        result = await manager.get_profile(sample_profile.id)

        assert result == sample_profile
        manager.repo.get_profile.assert_called_once_with(sample_profile.id)

    @pytest.mark.asyncio
    async def test_get_profile_not_found(self, manager):
        """Test getting non-existent profile."""
        manager.repo.get_profile = AsyncMock(return_value=None)

        result = await manager.get_profile(uuid4())

        assert result is None

    @pytest.mark.asyncio
    async def test_get_profile_by_name(self, manager, sample_profile):
        """Test getting profile by name."""
        manager.repo.get_profile_by_name = AsyncMock(return_value=sample_profile)

        result = await manager.get_profile_by_name("Test Profile")

        assert result == sample_profile


class TestListProfiles:
    """Tests for profile listing."""

    @pytest.mark.asyncio
    async def test_list_profiles_all(self, manager, sample_profile):
        """Test listing all profiles."""
        manager.repo.list_profiles = AsyncMock(return_value=([sample_profile], 1))

        profiles, total = await manager.list_profiles()

        assert len(profiles) == 1
        assert total == 1

    @pytest.mark.asyncio
    async def test_list_profiles_with_filters(self, manager, sample_profile):
        """Test listing profiles with filters."""
        manager.repo.list_profiles = AsyncMock(return_value=([sample_profile], 1))

        await manager.list_profiles(
            provider="chatterbox",
            tags=["test"],
            use_case="testing",
            is_active=True,
            limit=50,
            offset=10,
        )

        manager.repo.list_profiles.assert_called_once_with(
            provider="chatterbox",
            tags=["test"],
            use_case="testing",
            is_active=True,
            limit=50,
            offset=10,
        )


class TestUpdateProfile:
    """Tests for profile updates."""

    @pytest.mark.asyncio
    async def test_update_profile_success(self, manager, sample_profile):
        """Test successful profile update."""
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager.repo.update_profile = AsyncMock(return_value=sample_profile)

        result = await manager.update_profile(
            profile_id=sample_profile.id,
            description="Updated description",
        )

        assert result is not None
        manager.repo.update_profile.assert_called_once()

    @pytest.mark.asyncio
    async def test_update_profile_not_found(self, manager):
        """Test updating non-existent profile."""
        manager.repo.get_profile = AsyncMock(return_value=None)

        with pytest.raises(ValueError, match="not found"):
            await manager.update_profile(
                profile_id=uuid4(),
                description="Updated",
            )

    @pytest.mark.asyncio
    async def test_update_profile_duplicate_name(self, manager, sample_profile):
        """Test updating profile to duplicate name."""
        other_profile = TTSProfile.create(
            name="Other Profile",
            provider="chatterbox",
            voice_id="nova",
            settings=TTSProfileSettings(speed=1.0),
        )
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager.repo.get_profile_by_name = AsyncMock(return_value=other_profile)

        with pytest.raises(ValueError, match="already exists"):
            await manager.update_profile(
                profile_id=sample_profile.id,
                name="Other Profile",
            )

    @pytest.mark.asyncio
    async def test_update_profile_merges_settings(self, manager, sample_profile):
        """Test that settings are merged on update."""
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager.repo.update_profile = AsyncMock(side_effect=lambda p: p)

        result = await manager.update_profile(
            profile_id=sample_profile.id,
            settings={"speed": 1.5},  # Only update speed
        )

        # Original exaggeration should be preserved
        assert result.settings.speed == 1.5
        assert result.settings.exaggeration == 0.5

    @pytest.mark.asyncio
    async def test_update_profile_regenerates_sample_on_tts_change(self, manager_with_tts, sample_profile):
        """Test sample regeneration when TTS settings change."""
        manager_with_tts.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager_with_tts.repo.update_profile = AsyncMock(side_effect=lambda p: p)

        with patch("builtins.open", MagicMock()):
            await manager_with_tts.update_profile(
                profile_id=sample_profile.id,
                voice_id="new_voice",
            )

        manager_with_tts.tts_pool.generate_with_priority.assert_called_once()


class TestDeleteProfile:
    """Tests for profile deletion."""

    @pytest.mark.asyncio
    async def test_delete_profile_soft(self, manager):
        """Test soft deleting a profile."""
        manager.repo.delete_profile = AsyncMock(return_value=True)

        result = await manager.delete_profile(uuid4(), soft=True)

        assert result is True
        manager.repo.delete_profile.assert_called_once()

    @pytest.mark.asyncio
    async def test_delete_profile_hard(self, manager, sample_profile):
        """Test hard deleting a profile."""
        sample_profile.sample_audio_path = "/tmp/samples/test.wav"
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager.repo.delete_profile = AsyncMock(return_value=True)

        with patch.object(Path, "exists", return_value=True):
            with patch.object(Path, "unlink"):
                result = await manager.delete_profile(sample_profile.id, soft=False)

        assert result is True

    @pytest.mark.asyncio
    async def test_delete_profile_not_found(self, manager):
        """Test deleting non-existent profile."""
        manager.repo.delete_profile = AsyncMock(return_value=False)

        result = await manager.delete_profile(uuid4())

        assert result is False


class TestDefaultProfile:
    """Tests for default profile management."""

    @pytest.mark.asyncio
    async def test_set_default_profile(self, manager, sample_profile):
        """Test setting default profile."""
        sample_profile.is_active = True
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager.repo.set_default_profile = AsyncMock()

        await manager.set_default_profile(sample_profile.id)

        manager.repo.set_default_profile.assert_called_once_with(sample_profile.id)

    @pytest.mark.asyncio
    async def test_set_default_profile_not_found(self, manager):
        """Test setting default for non-existent profile."""
        manager.repo.get_profile = AsyncMock(return_value=None)

        with pytest.raises(ValueError, match="not found"):
            await manager.set_default_profile(uuid4())

    @pytest.mark.asyncio
    async def test_set_default_inactive_profile(self, manager, sample_profile):
        """Test setting inactive profile as default."""
        sample_profile.is_active = False
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)

        with pytest.raises(ValueError, match="inactive"):
            await manager.set_default_profile(sample_profile.id)

    @pytest.mark.asyncio
    async def test_get_default_profile(self, manager, sample_profile):
        """Test getting default profile."""
        sample_profile.is_default = True
        manager.repo.list_profiles = AsyncMock(return_value=([sample_profile], 1))

        result = await manager.get_default_profile()

        assert result == sample_profile

    @pytest.mark.asyncio
    async def test_get_default_profile_none(self, manager):
        """Test getting default when none set."""
        manager.repo.list_profiles = AsyncMock(return_value=([], 0))

        result = await manager.get_default_profile()

        assert result is None


# =============================================================================
# Module Association Tests
# =============================================================================


class TestModuleAssociations:
    """Tests for module-profile associations."""

    @pytest.mark.asyncio
    async def test_assign_to_module(self, manager, sample_profile):
        """Test assigning profile to module."""
        sample_profile.is_active = True
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager.repo.assign_profile_to_module = AsyncMock(
            return_value=TTSModuleProfile(
                id=uuid4(),
                module_id="knowledge-bowl",
                profile_id=sample_profile.id,
                context="questions",
                priority=10,
            )
        )

        result = await manager.assign_to_module(
            profile_id=sample_profile.id,
            module_id="knowledge-bowl",
            context="questions",
            priority=10,
        )

        assert result.module_id == "knowledge-bowl"
        assert result.context == "questions"

    @pytest.mark.asyncio
    async def test_assign_inactive_profile_to_module(self, manager, sample_profile):
        """Test assigning inactive profile fails."""
        sample_profile.is_active = False
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)

        with pytest.raises(ValueError, match="inactive"):
            await manager.assign_to_module(
                profile_id=sample_profile.id,
                module_id="knowledge-bowl",
            )

    @pytest.mark.asyncio
    async def test_get_module_profiles(self, manager, sample_profile):
        """Test getting profiles for a module."""
        assoc = TTSModuleProfile(
            id=uuid4(),
            module_id="knowledge-bowl",
            profile_id=sample_profile.id,
        )
        manager.repo.get_module_profiles = AsyncMock(return_value=[(assoc, sample_profile)])

        results = await manager.get_module_profiles("knowledge-bowl")

        assert len(results) == 1
        assert results[0][1] == sample_profile

    @pytest.mark.asyncio
    async def test_get_module_profiles_with_context_filter(self, manager, sample_profile):
        """Test filtering module profiles by context."""
        assoc_questions = TTSModuleProfile(
            id=uuid4(),
            module_id="knowledge-bowl",
            profile_id=sample_profile.id,
            context="questions",
        )
        assoc_any = TTSModuleProfile(
            id=uuid4(),
            module_id="knowledge-bowl",
            profile_id=sample_profile.id,
            context=None,  # Matches any context
        )
        manager.repo.get_module_profiles = AsyncMock(
            return_value=[
                (assoc_questions, sample_profile),
                (assoc_any, sample_profile),
            ]
        )

        results = await manager.get_module_profiles("knowledge-bowl", context="questions")

        # Should return both: exact match and NULL context
        assert len(results) == 2

    @pytest.mark.asyncio
    async def test_get_best_profile_for_module(self, manager, sample_profile):
        """Test getting best profile for module."""
        assoc = TTSModuleProfile(
            id=uuid4(),
            module_id="knowledge-bowl",
            profile_id=sample_profile.id,
            priority=10,
        )
        manager.repo.get_module_profiles = AsyncMock(return_value=[(assoc, sample_profile)])

        result = await manager.get_best_profile_for_module("knowledge-bowl")

        assert result == sample_profile

    @pytest.mark.asyncio
    async def test_get_best_profile_fallback_to_default(self, manager, sample_profile):
        """Test falling back to default when no module profile."""
        sample_profile.is_default = True
        manager.repo.get_module_profiles = AsyncMock(return_value=[])
        manager.repo.list_profiles = AsyncMock(return_value=([sample_profile], 1))

        result = await manager.get_best_profile_for_module("unknown-module")

        assert result == sample_profile

    @pytest.mark.asyncio
    async def test_remove_from_module(self, manager):
        """Test removing profile from module."""
        manager.repo.remove_profile_from_module = AsyncMock(return_value=True)

        result = await manager.remove_from_module(uuid4(), "knowledge-bowl")

        assert result is True


# =============================================================================
# Profile from Variant Tests
# =============================================================================


class TestCreateFromVariant:
    """Tests for creating profiles from comparison variants."""

    @pytest.mark.asyncio
    async def test_create_from_variant(self, manager, sample_variant, sample_profile):
        """Test creating profile from variant."""
        session = TTSComparisonSession.create(
            name="Test Session",
            samples=[],
            configurations=[],
        )
        manager.repo.get_variant = AsyncMock(return_value=sample_variant)
        manager.repo.get_session = AsyncMock(return_value=session)
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(return_value=sample_profile)

        result = await manager.create_from_variant(
            variant_id=sample_variant.id,
            name="New Profile from Variant",
            tags=["comparison-winner"],
        )

        assert result is not None
        manager.repo.create_profile.assert_called_once()

    @pytest.mark.asyncio
    async def test_create_from_variant_not_found(self, manager):
        """Test creating from non-existent variant."""
        manager.repo.get_variant = AsyncMock(return_value=None)

        with pytest.raises(ValueError, match="not found"):
            await manager.create_from_variant(
                variant_id=uuid4(),
                name="New Profile",
            )

    @pytest.mark.asyncio
    async def test_create_from_variant_auto_description(self, manager, sample_variant, sample_profile):
        """Test auto-generated description from variant."""
        session = TTSComparisonSession.create(
            name="Voice Comparison",
            samples=[],
            configurations=[],
        )
        manager.repo.get_variant = AsyncMock(return_value=sample_variant)
        manager.repo.get_session = AsyncMock(return_value=session)
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(side_effect=lambda p: p)

        result = await manager.create_from_variant(
            variant_id=sample_variant.id,
            name="Winner",
            # No description provided
        )

        assert "Voice Comparison" in result.description


# =============================================================================
# Export/Import Tests
# =============================================================================


class TestExportImport:
    """Tests for profile export and import."""

    @pytest.mark.asyncio
    async def test_export_profile(self, manager, sample_profile):
        """Test exporting a profile."""
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)

        export = await manager.export_profile(sample_profile.id)

        assert export["name"] == sample_profile.name
        assert export["provider"] == sample_profile.provider
        assert export["voice_id"] == sample_profile.voice_id
        assert "exported_at" in export

    @pytest.mark.asyncio
    async def test_export_profile_not_found(self, manager):
        """Test exporting non-existent profile."""
        manager.repo.get_profile = AsyncMock(return_value=None)

        with pytest.raises(ValueError, match="not found"):
            await manager.export_profile(uuid4())

    @pytest.mark.asyncio
    async def test_import_profile(self, manager, sample_profile):
        """Test importing a profile."""
        export_data = {
            "name": "Imported Profile",
            "provider": "chatterbox",
            "voice_id": "nova",
            "settings": {"speed": 1.0},
            "description": "Imported from export",
            "tags": ["imported"],
        }
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(return_value=sample_profile)

        result = await manager.import_profile(export_data)

        assert result is not None

    @pytest.mark.asyncio
    async def test_import_profile_with_name_override(self, manager, sample_profile):
        """Test importing with name override."""
        export_data = {
            "name": "Original Name",
            "provider": "chatterbox",
            "voice_id": "nova",
        }
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(side_effect=lambda p: p)

        result = await manager.import_profile(export_data, name_override="Overridden Name")

        assert result.name == "Overridden Name"


# =============================================================================
# Bulk Operations Tests
# =============================================================================


class TestBulkOperations:
    """Tests for bulk profile operations."""

    @pytest.mark.asyncio
    async def test_get_profiles_by_ids(self, manager, sample_profile):
        """Test getting multiple profiles by ID."""
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)

        ids = [uuid4(), uuid4(), uuid4()]
        results = await manager.get_profiles_by_ids(ids)

        assert len(results) == 3
        assert manager.repo.get_profile.call_count == 3

    @pytest.mark.asyncio
    async def test_get_profiles_by_ids_some_not_found(self, manager, sample_profile):
        """Test getting profiles where some don't exist."""
        manager.repo.get_profile = AsyncMock(
            side_effect=[sample_profile, None, sample_profile]
        )

        ids = [uuid4(), uuid4(), uuid4()]
        results = await manager.get_profiles_by_ids(ids)

        assert len(results) == 2

    @pytest.mark.asyncio
    async def test_duplicate_profile(self, manager, sample_profile):
        """Test duplicating a profile."""
        manager.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager.repo.get_profile_by_name = AsyncMock(return_value=None)
        manager.repo.create_profile = AsyncMock(side_effect=lambda p: p)

        result = await manager.duplicate_profile(
            profile_id=sample_profile.id,
            new_name="Duplicate Profile",
        )

        assert result.name == "Duplicate Profile"
        assert result.provider == sample_profile.provider
        assert result.voice_id == sample_profile.voice_id

    @pytest.mark.asyncio
    async def test_duplicate_profile_not_found(self, manager):
        """Test duplicating non-existent profile."""
        manager.repo.get_profile = AsyncMock(return_value=None)

        with pytest.raises(ValueError, match="not found"):
            await manager.duplicate_profile(
                profile_id=uuid4(),
                new_name="Duplicate",
            )


# =============================================================================
# TTS Config Conversion Tests
# =============================================================================


class TestTTSConfigConversion:
    """Tests for profile to TTS config conversion."""

    def test_profile_to_tts_config_basic(self, manager, sample_profile):
        """Test basic config conversion."""
        config = manager.profile_to_tts_config(sample_profile)

        assert config["provider"] == "chatterbox"
        assert config["voice_id"] == "nova"
        assert config["speed"] == 1.0

    def test_profile_to_tts_config_chatterbox(self, manager, sample_profile):
        """Test chatterbox config includes extra settings."""
        config = manager.profile_to_tts_config(sample_profile)

        assert "chatterbox_config" in config
        assert config["chatterbox_config"]["exaggeration"] == 0.5
        assert config["chatterbox_config"]["cfg_weight"] == 0.5

    def test_profile_to_tts_config_non_chatterbox(self, manager, sample_profile):
        """Test non-chatterbox config doesn't include chatterbox settings."""
        sample_profile.provider = "piper"

        config = manager.profile_to_tts_config(sample_profile)

        assert "chatterbox_config" not in config

    def test_profile_to_tts_config_with_language(self, manager, sample_profile):
        """Test config includes language when set."""
        sample_profile.settings.language = "en-US"

        config = manager.profile_to_tts_config(sample_profile)

        assert config["language"] == "en-US"


# =============================================================================
# Sample Audio Tests
# =============================================================================


class TestSampleAudio:
    """Tests for sample audio generation."""

    @pytest.mark.asyncio
    async def test_regenerate_sample(self, manager_with_tts, sample_profile):
        """Test regenerating sample audio."""
        manager_with_tts.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager_with_tts.repo.update_profile = AsyncMock(return_value=sample_profile)

        with patch("builtins.open", MagicMock()):
            result = await manager_with_tts.regenerate_sample(sample_profile.id)

        assert result is not None
        manager_with_tts.tts_pool.generate_with_priority.assert_called_once()

    @pytest.mark.asyncio
    async def test_regenerate_sample_with_custom_text(self, manager_with_tts, sample_profile):
        """Test regenerating sample with custom text."""
        manager_with_tts.repo.get_profile = AsyncMock(return_value=sample_profile)
        manager_with_tts.repo.update_profile = AsyncMock(side_effect=lambda p: p)

        with patch("builtins.open", MagicMock()):
            result = await manager_with_tts.regenerate_sample(
                sample_profile.id,
                sample_text="Custom sample text",
            )

        assert result.sample_text == "Custom sample text"

    @pytest.mark.asyncio
    async def test_regenerate_sample_not_found(self, manager_with_tts):
        """Test regenerating for non-existent profile."""
        manager_with_tts.repo.get_profile = AsyncMock(return_value=None)

        with pytest.raises(ValueError, match="not found"):
            await manager_with_tts.regenerate_sample(uuid4())

    @pytest.mark.asyncio
    async def test_generate_sample_without_tts_pool(self, manager, sample_profile):
        """Test sample generation logs warning without TTS pool."""
        # Manager without TTS pool should not crash
        await manager._generate_sample_audio(sample_profile)
        # Just verify it doesn't raise
