# TTS Comparison Manager
# High-level service for managing comparison sessions
# Coordinates variant generation, ratings, and profile creation

import asyncio
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from uuid import UUID

from .models import (
    TTSComparisonSession,
    TTSComparisonVariant,
    TTSComparisonRating,
    TTSProfile,
    TTSProfileSettings,
    SessionStatus,
    VariantStatus,
)
from .repository import TTSPregenRepository

logger = logging.getLogger(__name__)

# Default storage directory
DEFAULT_COMPARISON_DIR = "data/tts-pregenerated/comparisons"


class TTSComparisonManager:
    """Service for managing TTS comparison sessions.

    Provides:
    - Session creation with sample and configuration definitions
    - Variant audio generation
    - Rating management
    - Profile creation from winning variants
    """

    def __init__(
        self,
        repo: TTSPregenRepository,
        tts_pool: Optional[Any] = None,
        storage_dir: str = DEFAULT_COMPARISON_DIR,
    ):
        """Initialize the comparison manager.

        Args:
            repo: Repository for database operations
            tts_pool: TTS resource pool for audio generation
            storage_dir: Directory for storing comparison audio files
        """
        self.repo = repo
        self.tts_pool = tts_pool
        self.storage_dir = Path(storage_dir)

        # Ensure storage directory exists
        self.storage_dir.mkdir(parents=True, exist_ok=True)

    # =========================================================================
    # Session Management
    # =========================================================================

    async def create_session(
        self,
        name: str,
        samples: List[Dict[str, Any]],
        configurations: List[Dict[str, Any]],
        description: Optional[str] = None,
    ) -> TTSComparisonSession:
        """Create a new comparison session.

        Args:
            name: Session name
            samples: List of text samples [{text, source_ref?}]
            configurations: List of TTS configurations [{name, provider, voice_id, settings}]
            description: Optional session description

        Returns:
            Created session

        Raises:
            ValueError: If samples or configurations are empty
        """
        if not samples:
            raise ValueError("At least one sample is required")
        if not configurations:
            raise ValueError("At least one configuration is required")

        # Validate configurations
        for i, config in enumerate(configurations):
            if "provider" not in config:
                raise ValueError(f"Configuration {i} missing 'provider'")
            if "voice_id" not in config:
                raise ValueError(f"Configuration {i} missing 'voice_id'")
            if "name" not in config:
                config["name"] = f"Config {i + 1}"

        session = TTSComparisonSession.create(
            name=name,
            samples=samples,
            configurations=configurations,
            description=description,
        )

        # Create session directory
        session_dir = self.storage_dir / str(session.id)
        session_dir.mkdir(parents=True, exist_ok=True)

        # Save to database
        await self.repo.create_session(session)

        # Create all variants (but don't generate audio yet)
        variants = []
        for sample_idx, sample in enumerate(samples):
            for config_idx, config in enumerate(configurations):
                variant = TTSComparisonVariant.create(
                    session_id=session.id,
                    sample_index=sample_idx,
                    config_index=config_idx,
                    text_content=sample["text"],
                    tts_config={
                        "name": config.get("name"),
                        "provider": config["provider"],
                        "voice_id": config["voice_id"],
                        "settings": config.get("settings", {}),
                    },
                )
                variants.append(variant)

        if variants:
            await self.repo.create_variants(variants)

        logger.info(
            f"Created comparison session '{name}' with {len(samples)} samples, "
            f"{len(configurations)} configurations, {len(variants)} variants"
        )

        return session

    async def get_session(self, session_id: UUID) -> Optional[TTSComparisonSession]:
        """Get session by ID."""
        return await self.repo.get_session(session_id)

    async def list_sessions(
        self,
        status: Optional[SessionStatus] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> Tuple[List[TTSComparisonSession], int]:
        """List comparison sessions with optional filtering."""
        return await self.repo.list_sessions(
            status=status,
            limit=limit,
            offset=offset,
        )

    async def delete_session(self, session_id: UUID) -> bool:
        """Delete a session and its associated files.

        Args:
            session_id: Session ID to delete

        Returns:
            True if deleted, False if not found
        """
        # Get session to find its storage directory
        session = await self.repo.get_session(session_id)
        if not session:
            return False

        # Delete from database (cascades to variants and ratings)
        deleted = await self.repo.delete_session(session_id)

        if deleted:
            # Clean up storage directory
            session_dir = self.storage_dir / str(session_id)
            if session_dir.exists():
                import shutil
                shutil.rmtree(session_dir, ignore_errors=True)

            logger.info(f"Deleted comparison session {session_id}")

        return deleted

    # =========================================================================
    # Variant Generation
    # =========================================================================

    async def generate_variants(
        self,
        session_id: UUID,
        regenerate: bool = False,
    ) -> TTSComparisonSession:
        """Generate audio for all variants in a session.

        Args:
            session_id: Session ID
            regenerate: If True, regenerate all variants including completed ones

        Returns:
            Updated session

        Raises:
            ValueError: If session not found
        """
        session = await self.repo.get_session(session_id)
        if not session:
            raise ValueError(f"Session {session_id} not found")

        if not self.tts_pool:
            raise ValueError("No TTS pool available for generation")

        # Import Priority with fallback
        try:
            from tts_cache.resource_pool import Priority
        except ImportError:
            from enum import IntEnum

            class Priority(IntEnum):
                INTERACTIVE = 0
                PREFETCH = 1
                SCHEDULED = 2

        # Update session status
        await self.repo.update_session_status(session_id, SessionStatus.GENERATING)

        # Get variants
        variants = await self.repo.get_session_variants(session_id)
        if regenerate:
            to_generate = variants
        else:
            to_generate = [v for v in variants if v.status != VariantStatus.READY]

        session_dir = self.storage_dir / str(session_id)
        session_dir.mkdir(parents=True, exist_ok=True)

        success_count = 0
        fail_count = 0

        for variant in to_generate:
            try:
                await self.repo.update_variant_status(
                    variant.id, VariantStatus.GENERATING
                )

                # Build TTS config
                config = variant.tts_config
                chatterbox_config = None
                if config.get("provider") == "chatterbox":
                    settings = config.get("settings", {})
                    chatterbox_config = {
                        "exaggeration": settings.get("exaggeration"),
                        "cfg_weight": settings.get("cfg_weight"),
                    }

                # Generate audio
                audio_data, sample_rate, duration = await self.tts_pool.generate_with_priority(
                    text=variant.text_content,
                    voice_id=config.get("voice_id"),
                    provider=config.get("provider"),
                    speed=config.get("settings", {}).get("speed", 1.0),
                    chatterbox_config=chatterbox_config,
                    priority=Priority.SCHEDULED,
                )

                # Save audio file
                filename = f"variant_{variant.sample_index}_{variant.config_index}.wav"
                output_path = session_dir / filename

                import wave
                with wave.open(str(output_path), "wb") as wav_file:
                    wav_file.setnchannels(1)
                    wav_file.setsampwidth(2)  # 16-bit
                    wav_file.setframerate(sample_rate)
                    wav_file.writeframes(audio_data)

                # Update variant status
                await self.repo.update_variant_status(
                    variant.id,
                    VariantStatus.READY,
                    output_file=str(output_path),
                    duration_seconds=duration,
                )

                success_count += 1

            except Exception as e:
                logger.error(f"Failed to generate variant {variant.id}: {e}")
                await self.repo.update_variant_status(
                    variant.id,
                    VariantStatus.FAILED,
                    error=str(e),
                )
                fail_count += 1

        # Update session status
        if fail_count == 0:
            new_status = SessionStatus.READY
        elif success_count == 0:
            new_status = SessionStatus.DRAFT  # All failed, back to draft
        else:
            new_status = SessionStatus.READY  # Partial success is still ready

        await self.repo.update_session_status(session_id, new_status)

        logger.info(
            f"Generated {success_count} variants for session {session_id} "
            f"({fail_count} failed)"
        )

        # Return updated session
        return await self.repo.get_session(session_id)

    async def get_session_with_variants(
        self, session_id: UUID
    ) -> Tuple[Optional[TTSComparisonSession], List[TTSComparisonVariant], Dict[UUID, TTSComparisonRating]]:
        """Get session with all its variants and ratings.

        Args:
            session_id: Session ID

        Returns:
            Tuple of (session, variants, ratings_by_variant_id)
        """
        session = await self.repo.get_session(session_id)
        if not session:
            return None, [], {}

        variants = await self.repo.get_session_variants(session_id)
        ratings = await self.repo.get_session_ratings(session_id)

        return session, variants, ratings

    async def get_variant(self, variant_id: UUID) -> Optional[TTSComparisonVariant]:
        """Get a specific variant."""
        return await self.repo.get_variant(variant_id)

    # =========================================================================
    # Rating Management
    # =========================================================================

    async def rate_variant(
        self,
        variant_id: UUID,
        rating: int,
        notes: Optional[str] = None,
    ) -> TTSComparisonRating:
        """Rate a variant.

        Args:
            variant_id: Variant ID
            rating: Rating value (1-5)
            notes: Optional notes

        Returns:
            Created or updated rating

        Raises:
            ValueError: If variant not found or rating out of range
        """
        if rating < 1 or rating > 5:
            raise ValueError("Rating must be between 1 and 5")

        variant = await self.repo.get_variant(variant_id)
        if not variant:
            raise ValueError(f"Variant {variant_id} not found")

        rating_obj = TTSComparisonRating.create(
            variant_id=variant_id,
            rating=rating,
            notes=notes,
        )

        return await self.repo.create_or_update_rating(rating_obj)

    async def get_variant_rating(self, variant_id: UUID) -> Optional[TTSComparisonRating]:
        """Get rating for a variant."""
        return await self.repo.get_variant_rating(variant_id)

    # =========================================================================
    # Profile Creation
    # =========================================================================

    async def create_profile_from_variant(
        self,
        variant_id: UUID,
        name: str,
        description: Optional[str] = None,
        tags: Optional[List[str]] = None,
    ) -> TTSProfile:
        """Create a TTS profile from a comparison variant.

        This promotes a winning variant's configuration to a reusable profile.

        Args:
            variant_id: Variant ID
            name: Profile name
            description: Optional description
            tags: Optional tags

        Returns:
            Created profile

        Raises:
            ValueError: If variant not found or name already exists
        """
        variant = await self.repo.get_variant(variant_id)
        if not variant:
            raise ValueError(f"Variant {variant_id} not found")

        # Check name uniqueness
        existing = await self.repo.get_profile_by_name(name)
        if existing:
            raise ValueError(f"Profile with name '{name}' already exists")

        # Get session for description auto-generation
        session = await self.repo.get_session(variant.session_id)

        # Build description if not provided
        if not description and session:
            description = f"Created from comparison session '{session.name}'"

        # Extract settings from variant config
        config = variant.tts_config
        settings_dict = config.get("settings", {})
        settings = TTSProfileSettings(
            speed=settings_dict.get("speed", 1.0),
            exaggeration=settings_dict.get("exaggeration"),
            cfg_weight=settings_dict.get("cfg_weight"),
            language=settings_dict.get("language"),
        )

        # Create profile
        profile = TTSProfile.create(
            name=name,
            provider=config.get("provider"),
            voice_id=config.get("voice_id"),
            settings=settings,
            description=description,
            tags=tags or ["comparison-winner"],
            created_from_session_id=variant.session_id,
        )

        # Copy sample audio if variant has one
        if variant.output_file:
            profile.sample_audio_path = variant.output_file
            profile.sample_text = variant.text_content

        await self.repo.create_profile(profile)

        logger.info(
            f"Created profile '{name}' from variant {variant_id} "
            f"(session: {variant.session_id})"
        )

        return profile

    # =========================================================================
    # Utility Methods
    # =========================================================================

    async def get_audio_file_path(self, variant_id: UUID) -> Optional[str]:
        """Get the audio file path for a variant.

        Args:
            variant_id: Variant ID

        Returns:
            File path if variant exists and has audio, None otherwise
        """
        variant = await self.repo.get_variant(variant_id)
        if not variant or not variant.output_file:
            return None

        # Verify file exists
        if not os.path.exists(variant.output_file):
            return None

        return variant.output_file

    async def get_session_summary(self, session_id: UUID) -> Optional[Dict[str, Any]]:
        """Get a summary of session results including ratings.

        Args:
            session_id: Session ID

        Returns:
            Summary dict with configuration rankings, or None if not found
        """
        session, variants, ratings = await self.get_session_with_variants(session_id)
        if not session:
            return None

        # Group variants by configuration
        config_stats: Dict[int, Dict[str, Any]] = {}
        for variant in variants:
            idx = variant.config_index
            if idx not in config_stats:
                config_stats[idx] = {
                    "config_index": idx,
                    "config_name": variant.tts_config.get("name", f"Config {idx + 1}"),
                    "ratings": [],
                    "ready_count": 0,
                    "failed_count": 0,
                }

            if variant.status == VariantStatus.READY:
                config_stats[idx]["ready_count"] += 1
            elif variant.status == VariantStatus.FAILED:
                config_stats[idx]["failed_count"] += 1

            if variant.id in ratings:
                config_stats[idx]["ratings"].append(ratings[variant.id].rating)

        # Calculate averages
        results = []
        for idx, stats in sorted(config_stats.items()):
            avg_rating = (
                sum(stats["ratings"]) / len(stats["ratings"])
                if stats["ratings"]
                else None
            )
            results.append({
                "config_index": idx,
                "config_name": stats["config_name"],
                "average_rating": round(avg_rating, 2) if avg_rating else None,
                "rating_count": len(stats["ratings"]),
                "ready_count": stats["ready_count"],
                "failed_count": stats["failed_count"],
            })

        # Sort by average rating (highest first)
        results.sort(
            key=lambda x: (x["average_rating"] or 0, x["rating_count"]),
            reverse=True,
        )

        return {
            "session_id": str(session.id),
            "session_name": session.name,
            "status": session.status.value,
            "total_samples": session.sample_count,
            "total_configurations": session.config_count,
            "total_variants": session.total_variants,
            "configuration_rankings": results,
        }
