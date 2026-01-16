# TTS Profile Manager
# High-level service for managing TTS profiles and module associations

import asyncio
import hashlib
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from uuid import UUID, uuid4

from .models import (
    TTSProfile,
    TTSProfileSettings,
    TTSModuleProfile,
    SessionStatus,
)
from .repository import TTSPregenRepository

logger = logging.getLogger(__name__)

# Default sample text for profile previews
DEFAULT_SAMPLE_TEXT = "Welcome to UnaMentis. Let me help you learn something new today."

# Output directory for profile samples
PROFILE_SAMPLES_DIR = Path(__file__).parent.parent / "data" / "tts-pregenerated" / "profile-samples"


class TTSProfileManager:
    """High-level service for TTS profile management.

    Provides:
    - Profile CRUD operations with validation
    - Sample audio generation for profile previews
    - Module-profile association management
    - Profile creation from comparison session variants

    Usage:
        manager = TTSProfileManager(db_pool, tts_resource_pool)
        profile = await manager.create_profile(
            name="Knowledge Bowl Tutor",
            provider="chatterbox",
            voice_id="nova",
            settings={"speed": 1.1, "exaggeration": 0.7}
        )
    """

    def __init__(self, db_pool, tts_resource_pool=None):
        """Initialize profile manager.

        Args:
            db_pool: asyncpg connection pool
            tts_resource_pool: Optional TTSResourcePool for sample generation
        """
        self.repo = TTSPregenRepository(db_pool)
        self.tts_pool = tts_resource_pool
        self._ensure_samples_dir()

    def _ensure_samples_dir(self):
        """Ensure the samples directory exists."""
        PROFILE_SAMPLES_DIR.mkdir(parents=True, exist_ok=True)

    # =========================================================================
    # PROFILE CRUD
    # =========================================================================

    async def create_profile(
        self,
        name: str,
        provider: str,
        voice_id: str,
        settings: Optional[Dict[str, Any]] = None,
        description: Optional[str] = None,
        tags: Optional[List[str]] = None,
        use_case: Optional[str] = None,
        is_default: bool = False,
        generate_sample: bool = True,
        sample_text: Optional[str] = None,
        created_from_session_id: Optional[UUID] = None,
    ) -> TTSProfile:
        """Create a new TTS profile.

        Args:
            name: Unique profile name
            provider: TTS provider (chatterbox, vibevoice, piper)
            voice_id: Voice identifier for the provider
            settings: Provider-specific settings dict
            description: Optional profile description
            tags: Optional categorization tags
            use_case: Optional use case identifier
            is_default: Whether to set as system default
            generate_sample: Whether to generate sample audio
            sample_text: Custom text for sample audio
            created_from_session_id: Link to comparison session if created from variant

        Returns:
            Created TTSProfile

        Raises:
            ValueError: If profile name already exists or validation fails
        """
        # Validate name uniqueness
        existing = await self.repo.get_profile_by_name(name)
        if existing:
            raise ValueError(f"Profile with name '{name}' already exists")

        # Validate provider
        valid_providers = ["chatterbox", "vibevoice", "piper"]
        if provider not in valid_providers:
            raise ValueError(f"Invalid provider '{provider}'. Must be one of: {valid_providers}")

        # Create profile settings
        profile_settings = TTSProfileSettings.from_dict(settings or {})

        # Create profile
        profile = TTSProfile.create(
            name=name,
            provider=provider,
            voice_id=voice_id,
            settings=profile_settings,
            description=description,
            tags=tags or [],
            use_case=use_case,
            is_default=is_default,
            created_from_session_id=created_from_session_id,
            sample_text=sample_text or DEFAULT_SAMPLE_TEXT,
        )

        # Save to database
        profile = await self.repo.create_profile(profile)

        # Handle default profile
        if is_default:
            await self.repo.set_default_profile(profile.id)

        # Generate sample audio if requested
        if generate_sample and self.tts_pool:
            try:
                await self._generate_sample_audio(profile)
                profile = await self.repo.update_profile(profile)
            except Exception as e:
                logger.warning(f"Failed to generate sample audio for profile {profile.id}: {e}")

        logger.info(f"Created TTS profile: {profile.name} ({profile.id})")
        return profile

    async def get_profile(self, profile_id: UUID) -> Optional[TTSProfile]:
        """Get a profile by ID."""
        return await self.repo.get_profile(profile_id)

    async def get_profile_by_name(self, name: str) -> Optional[TTSProfile]:
        """Get a profile by name."""
        return await self.repo.get_profile_by_name(name)

    async def list_profiles(
        self,
        provider: Optional[str] = None,
        tags: Optional[List[str]] = None,
        use_case: Optional[str] = None,
        is_active: Optional[bool] = True,
        limit: int = 100,
        offset: int = 0,
    ) -> Tuple[List[TTSProfile], int]:
        """List profiles with optional filtering.

        Args:
            provider: Filter by TTS provider
            tags: Filter by tags (any match)
            use_case: Filter by use case
            is_active: Filter by active status (default True)
            limit: Maximum results
            offset: Pagination offset

        Returns:
            Tuple of (profiles list, total count)
        """
        return await self.repo.list_profiles(
            provider=provider,
            tags=tags,
            use_case=use_case,
            is_active=is_active,
            limit=limit,
            offset=offset,
        )

    async def update_profile(
        self,
        profile_id: UUID,
        name: Optional[str] = None,
        description: Optional[str] = None,
        provider: Optional[str] = None,
        voice_id: Optional[str] = None,
        settings: Optional[Dict[str, Any]] = None,
        tags: Optional[List[str]] = None,
        use_case: Optional[str] = None,
        regenerate_sample: bool = False,
        sample_text: Optional[str] = None,
    ) -> TTSProfile:
        """Update an existing profile.

        Args:
            profile_id: Profile to update
            name: New name (if changing)
            description: New description
            provider: New provider (requires voice_id too)
            voice_id: New voice ID
            settings: New or merged settings
            tags: New tags (replaces existing)
            use_case: New use case
            regenerate_sample: Force regenerate sample audio
            sample_text: New sample text

        Returns:
            Updated TTSProfile

        Raises:
            ValueError: If profile not found or validation fails
        """
        profile = await self.repo.get_profile(profile_id)
        if not profile:
            raise ValueError(f"Profile {profile_id} not found")

        # Check name uniqueness if changing
        if name and name != profile.name:
            existing = await self.repo.get_profile_by_name(name)
            if existing:
                raise ValueError(f"Profile with name '{name}' already exists")
            profile.name = name

        # Update fields
        if description is not None:
            profile.description = description
        if provider is not None:
            profile.provider = provider
        if voice_id is not None:
            profile.voice_id = voice_id
        if settings is not None:
            # Merge settings
            current = profile.settings.to_dict()
            current.update(settings)
            profile.settings = TTSProfileSettings.from_dict(current)
        if tags is not None:
            profile.tags = tags
        if use_case is not None:
            profile.use_case = use_case
        if sample_text is not None:
            profile.sample_text = sample_text
            regenerate_sample = True

        # Save updates
        profile = await self.repo.update_profile(profile)

        # Regenerate sample if needed
        tts_changed = provider is not None or voice_id is not None or settings is not None
        if (regenerate_sample or tts_changed) and self.tts_pool:
            try:
                await self._generate_sample_audio(profile)
                profile = await self.repo.update_profile(profile)
            except Exception as e:
                logger.warning(f"Failed to regenerate sample audio for profile {profile.id}: {e}")

        logger.info(f"Updated TTS profile: {profile.name} ({profile.id})")
        return profile

    async def delete_profile(self, profile_id: UUID, soft: bool = True) -> bool:
        """Delete a profile.

        Args:
            profile_id: Profile to delete
            soft: If True, marks as inactive; if False, permanently deletes

        Returns:
            True if deleted
        """
        # Clean up sample audio file on hard delete
        if not soft:
            profile = await self.repo.get_profile(profile_id)
            if profile and profile.sample_audio_path:
                try:
                    sample_path = Path(profile.sample_audio_path)
                    if sample_path.exists():
                        sample_path.unlink()
                except Exception as e:
                    logger.warning(f"Failed to delete sample audio: {e}")

        return await self.repo.delete_profile(profile_id, soft=soft)

    async def set_default_profile(self, profile_id: UUID) -> None:
        """Set a profile as the system default."""
        profile = await self.repo.get_profile(profile_id)
        if not profile:
            raise ValueError(f"Profile {profile_id} not found")
        if not profile.is_active:
            raise ValueError("Cannot set inactive profile as default")

        await self.repo.set_default_profile(profile_id)
        logger.info(f"Set default TTS profile: {profile.name}")

    async def get_default_profile(self) -> Optional[TTSProfile]:
        """Get the current default profile."""
        profiles, _ = await self.repo.list_profiles(is_active=True, limit=1000)
        for profile in profiles:
            if profile.is_default:
                return profile
        return None

    # =========================================================================
    # SAMPLE AUDIO GENERATION
    # =========================================================================

    async def _generate_sample_audio(self, profile: TTSProfile) -> None:
        """Generate sample audio for a profile preview.

        Args:
            profile: Profile to generate sample for
        """
        if not self.tts_pool:
            logger.warning("No TTS pool available for sample generation")
            return

        # Import here to avoid circular imports
        try:
            from tts_cache.resource_pool import Priority
        except ImportError:
            # Fallback for testing context
            from enum import IntEnum

            class Priority(IntEnum):
                INTERACTIVE = 0
                PREFETCH = 1
                SCHEDULED = 2

        text = profile.sample_text or DEFAULT_SAMPLE_TEXT

        # Build chatterbox config if needed
        chatterbox_config = None
        if profile.provider == "chatterbox":
            chatterbox_config = {
                "exaggeration": profile.settings.exaggeration,
                "cfg_weight": profile.settings.cfg_weight,
            }

        try:
            # Generate audio with low priority
            audio_data, sample_rate, duration = await self.tts_pool.generate_with_priority(
                text=text,
                voice_id=profile.voice_id,
                provider=profile.provider,
                speed=profile.settings.speed,
                chatterbox_config=chatterbox_config,
                priority=Priority.SCHEDULED,
            )

            # Save to file (in thread to avoid blocking event loop)
            sample_filename = f"{profile.id}.wav"
            sample_path = PROFILE_SAMPLES_DIR / sample_filename

            def _write_sample(path: Path, data: bytes) -> None:
                with open(path, "wb") as f:
                    f.write(data)

            await asyncio.to_thread(_write_sample, sample_path, audio_data)

            # Update profile with sample path
            profile.sample_audio_path = str(sample_path)

            logger.info(f"Generated sample audio for profile {profile.name}: {sample_path}")

        except Exception as e:
            logger.error(f"Failed to generate sample for profile {profile.id}: {e}")
            raise

    async def regenerate_sample(
        self,
        profile_id: UUID,
        sample_text: Optional[str] = None,
    ) -> TTSProfile:
        """Regenerate sample audio for a profile.

        Args:
            profile_id: Profile to regenerate sample for
            sample_text: Optional new sample text

        Returns:
            Updated profile with new sample
        """
        profile = await self.repo.get_profile(profile_id)
        if not profile:
            raise ValueError(f"Profile {profile_id} not found")

        if sample_text:
            profile.sample_text = sample_text

        await self._generate_sample_audio(profile)
        return await self.repo.update_profile(profile)

    # =========================================================================
    # MODULE ASSOCIATIONS
    # =========================================================================

    async def assign_to_module(
        self,
        profile_id: UUID,
        module_id: str,
        context: Optional[str] = None,
        priority: int = 0,
    ) -> TTSModuleProfile:
        """Assign a profile to a module.

        Args:
            profile_id: Profile to assign
            module_id: Module identifier (e.g., 'knowledge-bowl')
            context: Optional context (e.g., 'questions', 'explanations')
            priority: Priority for this assignment (higher = preferred)

        Returns:
            Created module-profile association
        """
        profile = await self.repo.get_profile(profile_id)
        if not profile:
            raise ValueError(f"Profile {profile_id} not found")
        if not profile.is_active:
            raise ValueError("Cannot assign inactive profile to module")

        assoc = await self.repo.assign_profile_to_module(
            module_id=module_id,
            profile_id=profile_id,
            context=context,
            priority=priority,
        )

        logger.info(f"Assigned profile {profile.name} to module {module_id}")
        return assoc

    async def get_module_profiles(
        self,
        module_id: str,
        context: Optional[str] = None,
    ) -> List[Tuple[TTSModuleProfile, TTSProfile]]:
        """Get profiles assigned to a module.

        Args:
            module_id: Module identifier
            context: Optional filter by context

        Returns:
            List of (association, profile) tuples sorted by priority
        """
        results = await self.repo.get_module_profiles(module_id)

        # Filter by context if specified
        if context:
            results = [
                (assoc, profile)
                for assoc, profile in results
                if assoc.context is None or assoc.context == context
            ]

        return results

    async def get_best_profile_for_module(
        self,
        module_id: str,
        context: Optional[str] = None,
    ) -> Optional[TTSProfile]:
        """Get the best profile for a module context.

        Returns the highest priority profile matching the module and context,
        or the system default if no module-specific profile exists.

        Args:
            module_id: Module identifier
            context: Optional context

        Returns:
            Best matching profile or None
        """
        profiles = await self.get_module_profiles(module_id, context)
        if profiles:
            return profiles[0][1]  # Return highest priority profile

        # Fall back to system default
        return await self.get_default_profile()

    async def remove_from_module(self, profile_id: UUID, module_id: str) -> bool:
        """Remove a profile assignment from a module."""
        return await self.repo.remove_profile_from_module(module_id, profile_id)

    # =========================================================================
    # PROFILE CREATION FROM COMPARISON VARIANTS
    # =========================================================================

    async def create_from_variant(
        self,
        variant_id: UUID,
        name: str,
        description: Optional[str] = None,
        tags: Optional[List[str]] = None,
        use_case: Optional[str] = None,
    ) -> TTSProfile:
        """Create a profile from a comparison session variant.

        This allows promoting a winning variant from A/B testing to a
        reusable profile.

        Args:
            variant_id: Comparison variant to create profile from
            name: Name for the new profile
            description: Optional description
            tags: Optional tags
            use_case: Optional use case

        Returns:
            Created TTSProfile
        """
        # Get the variant
        variant = await self.repo.get_variant(variant_id)
        if not variant:
            raise ValueError(f"Variant {variant_id} not found")

        # Extract config from variant
        tts_config = variant.tts_config
        provider = tts_config.get("provider", "chatterbox")
        voice_id = tts_config.get("voice_id", "")

        # Build settings from config
        settings = {
            k: v
            for k, v in tts_config.items()
            if k not in ("provider", "voice_id")
        }

        # Create description if not provided
        if not description:
            session = await self.repo.get_session(variant.session_id)
            session_name = session.name if session else "comparison"
            description = f"Created from {session_name} variant (sample {variant.sample_index + 1}, config {variant.config_index + 1})"

        # Create the profile
        return await self.create_profile(
            name=name,
            provider=provider,
            voice_id=voice_id,
            settings=settings,
            description=description,
            tags=tags or ["from-comparison"],
            use_case=use_case,
            created_from_session_id=variant.session_id,
            sample_text=variant.text_content,
        )

    # =========================================================================
    # PROFILE EXPORT/IMPORT
    # =========================================================================

    def profile_to_tts_config(self, profile: TTSProfile) -> Dict[str, Any]:
        """Convert a profile to TTS config dict for generation.

        This format is compatible with TTSResourcePool.generate_with_priority().

        Args:
            profile: Profile to convert

        Returns:
            Dict with provider, voice_id, and settings
        """
        config = {
            "provider": profile.provider,
            "voice_id": profile.voice_id,
            "speed": profile.settings.speed,
        }

        if profile.provider == "chatterbox":
            config["chatterbox_config"] = {
                "exaggeration": profile.settings.exaggeration,
                "cfg_weight": profile.settings.cfg_weight,
            }

        if profile.settings.language:
            config["language"] = profile.settings.language

        return config

    async def export_profile(self, profile_id: UUID) -> Dict[str, Any]:
        """Export a profile to a portable dict format.

        Args:
            profile_id: Profile to export

        Returns:
            Dict that can be used for import
        """
        profile = await self.repo.get_profile(profile_id)
        if not profile:
            raise ValueError(f"Profile {profile_id} not found")

        return {
            "name": profile.name,
            "description": profile.description,
            "provider": profile.provider,
            "voice_id": profile.voice_id,
            "settings": profile.settings.to_dict(),
            "tags": profile.tags,
            "use_case": profile.use_case,
            "sample_text": profile.sample_text,
            "exported_at": datetime.now().isoformat(),
        }

    async def import_profile(
        self,
        data: Dict[str, Any],
        name_override: Optional[str] = None,
    ) -> TTSProfile:
        """Import a profile from exported data.

        Args:
            data: Exported profile data
            name_override: Override the profile name

        Returns:
            Created TTSProfile
        """
        return await self.create_profile(
            name=name_override or data["name"],
            provider=data["provider"],
            voice_id=data["voice_id"],
            settings=data.get("settings", {}),
            description=data.get("description"),
            tags=data.get("tags", []),
            use_case=data.get("use_case"),
            sample_text=data.get("sample_text"),
        )

    # =========================================================================
    # BULK OPERATIONS
    # =========================================================================

    async def get_profiles_by_ids(self, profile_ids: List[UUID]) -> Dict[UUID, TTSProfile]:
        """Get multiple profiles by their IDs.

        Args:
            profile_ids: List of profile IDs

        Returns:
            Dict mapping profile ID to profile
        """
        result = {}
        for profile_id in profile_ids:
            profile = await self.repo.get_profile(profile_id)
            if profile:
                result[profile_id] = profile
        return result

    async def duplicate_profile(
        self,
        profile_id: UUID,
        new_name: str,
        description: Optional[str] = None,
    ) -> TTSProfile:
        """Duplicate an existing profile with a new name.

        Args:
            profile_id: Profile to duplicate
            new_name: Name for the duplicate
            description: Optional new description

        Returns:
            New TTSProfile
        """
        source = await self.repo.get_profile(profile_id)
        if not source:
            raise ValueError(f"Profile {profile_id} not found")

        return await self.create_profile(
            name=new_name,
            provider=source.provider,
            voice_id=source.voice_id,
            settings=source.settings.to_dict(),
            description=description or f"Duplicate of {source.name}",
            tags=list(source.tags),
            use_case=source.use_case,
            sample_text=source.sample_text,
        )
