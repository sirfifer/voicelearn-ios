# TTS Pre-Generation Models
# Data classes for TTS profile management, batch generation, and comparison

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID, uuid4
import hashlib


def _utc_now() -> datetime:
    """Return current UTC time with timezone info."""
    return datetime.now(timezone.utc)


class JobStatus(str, Enum):
    """Status of a TTS pre-generation job."""
    PENDING = "pending"
    RUNNING = "running"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class ItemStatus(str, Enum):
    """Status of an individual item in a job."""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"


class SessionStatus(str, Enum):
    """Status of a comparison session."""
    DRAFT = "draft"
    GENERATING = "generating"
    READY = "ready"
    ARCHIVED = "archived"


class VariantStatus(str, Enum):
    """Status of a comparison variant."""
    PENDING = "pending"
    GENERATING = "generating"
    READY = "ready"
    FAILED = "failed"


@dataclass
class TTSProfileSettings:
    """Provider-specific TTS settings.

    Common settings work across all providers.
    Chatterbox-specific settings are only used when provider is 'chatterbox'.
    """
    # Common settings
    speed: float = 1.0

    # Chatterbox-specific
    exaggeration: Optional[float] = None
    cfg_weight: Optional[float] = None
    language: Optional[str] = None

    # Future extensibility
    extra: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        d: Dict[str, Any] = {"speed": self.speed}
        if self.exaggeration is not None:
            d["exaggeration"] = self.exaggeration
        if self.cfg_weight is not None:
            d["cfg_weight"] = self.cfg_weight
        if self.language is not None:
            d["language"] = self.language
        if self.extra:
            d["extra"] = self.extra
        return d

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "TTSProfileSettings":
        """Create from dictionary (JSON deserialization)."""
        return cls(
            speed=d.get("speed", 1.0),
            exaggeration=d.get("exaggeration"),
            cfg_weight=d.get("cfg_weight"),
            language=d.get("language"),
            extra=d.get("extra", {}),
        )


@dataclass
class TTSProfile:
    """A reusable TTS voice configuration.

    Profiles capture a specific combination of provider, voice, and settings
    that can be used for batch generation, module defaults, or comparison testing.
    """
    id: UUID
    name: str
    provider: str  # 'chatterbox', 'vibevoice', 'piper'
    voice_id: str
    settings: TTSProfileSettings

    # Metadata
    description: Optional[str] = None
    tags: List[str] = field(default_factory=list)
    use_case: Optional[str] = None  # 'tutoring', 'questions', 'explanations'

    # Status
    is_active: bool = True
    is_default: bool = False

    # Audit
    created_at: datetime = field(default_factory=_utc_now)
    updated_at: datetime = field(default_factory=_utc_now)
    created_from_session_id: Optional[UUID] = None

    # Preview
    sample_audio_path: Optional[str] = None
    sample_text: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON/API response."""
        return {
            "id": str(self.id),
            "name": self.name,
            "provider": self.provider,
            "voice_id": self.voice_id,
            "settings": self.settings.to_dict(),
            "description": self.description,
            "tags": self.tags,
            "use_case": self.use_case,
            "is_active": self.is_active,
            "is_default": self.is_default,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "created_from_session_id": str(self.created_from_session_id) if self.created_from_session_id else None,
            "sample_audio_path": self.sample_audio_path,
            "sample_text": self.sample_text,
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "TTSProfile":
        """Create from dictionary (JSON/database row)."""
        return cls(
            id=UUID(d["id"]) if isinstance(d["id"], str) else d["id"],
            name=d["name"],
            provider=d["provider"],
            voice_id=d["voice_id"],
            settings=TTSProfileSettings.from_dict(d.get("settings", {})),
            description=d.get("description"),
            tags=d.get("tags", []),
            use_case=d.get("use_case"),
            is_active=d.get("is_active", True),
            is_default=d.get("is_default", False),
            created_at=datetime.fromisoformat(d["created_at"]) if isinstance(d.get("created_at"), str) else d.get("created_at", _utc_now()),
            updated_at=datetime.fromisoformat(d["updated_at"]) if isinstance(d.get("updated_at"), str) else d.get("updated_at", _utc_now()),
            created_from_session_id=UUID(d["created_from_session_id"]) if d.get("created_from_session_id") else None,
            sample_audio_path=d.get("sample_audio_path"),
            sample_text=d.get("sample_text"),
        )

    @classmethod
    def create(
        cls,
        name: str,
        provider: str,
        voice_id: str,
        settings: Optional[TTSProfileSettings] = None,
        **kwargs: Any,
    ) -> "TTSProfile":
        """Factory method to create a new profile."""
        return cls(
            id=uuid4(),
            name=name,
            provider=provider,
            voice_id=voice_id,
            settings=settings or TTSProfileSettings(),
            **kwargs,
        )


@dataclass
class TTSModuleProfile:
    """Association between a module and a TTS profile."""
    id: UUID
    module_id: str  # 'knowledge-bowl', curriculum UUID, etc.
    profile_id: UUID
    context: Optional[str] = None  # 'questions', 'explanations', 'hints', or None for all
    priority: int = 0  # Higher = preferred when multiple match
    created_at: datetime = field(default_factory=_utc_now)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "id": str(self.id),
            "module_id": self.module_id,
            "profile_id": str(self.profile_id),
            "context": self.context,
            "priority": self.priority,
            "created_at": self.created_at.isoformat(),
        }


@dataclass
class TTSPregenJob:
    """A batch TTS pre-generation job.

    Jobs track the progress of generating audio for multiple text items,
    supporting pause/resume and graceful failure handling.
    """
    id: UUID
    name: str
    job_type: str  # 'batch' or 'comparison'
    status: JobStatus

    # Source
    source_type: str  # 'curriculum', 'knowledge-bowl', 'custom'
    source_id: Optional[str] = None

    # TTS configuration (either profile_id or tts_config)
    profile_id: Optional[UUID] = None
    tts_config: Optional[Dict[str, Any]] = None  # Inline config if no profile

    # Output
    output_format: str = "wav"
    normalize_volume: bool = False
    output_dir: str = ""

    # Progress
    total_items: int = 0
    completed_items: int = 0
    failed_items: int = 0
    current_item_index: int = 0
    current_item_text: Optional[str] = None

    # Timing
    created_at: datetime = field(default_factory=_utc_now)
    started_at: Optional[datetime] = None
    paused_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    updated_at: datetime = field(default_factory=_utc_now)

    # Error tracking
    last_error: Optional[str] = None
    consecutive_failures: int = 0

    @property
    def percent_complete(self) -> float:
        """Calculate completion percentage."""
        if self.total_items == 0:
            return 0.0
        return (self.completed_items / self.total_items) * 100

    @property
    def pending_items(self) -> int:
        """Calculate number of pending items."""
        return self.total_items - self.completed_items - self.failed_items

    @property
    def is_resumable(self) -> bool:
        """Check if job can be resumed."""
        return self.status in (JobStatus.PAUSED, JobStatus.FAILED)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON/API response."""
        return {
            "id": str(self.id),
            "name": self.name,
            "job_type": self.job_type,
            "status": self.status.value,
            "source_type": self.source_type,
            "source_id": self.source_id,
            "profile_id": str(self.profile_id) if self.profile_id else None,
            "tts_config": self.tts_config,
            "output_format": self.output_format,
            "normalize_volume": self.normalize_volume,
            "output_dir": self.output_dir,
            "progress": {
                "total": self.total_items,
                "completed": self.completed_items,
                "failed": self.failed_items,
                "pending": self.pending_items,
                "percent_complete": round(self.percent_complete, 1),
                "current_index": self.current_item_index,
                "current_text": self.current_item_text,
            },
            "created_at": self.created_at.isoformat(),
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "paused_at": self.paused_at.isoformat() if self.paused_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "updated_at": self.updated_at.isoformat(),
            "last_error": self.last_error,
            "consecutive_failures": self.consecutive_failures,
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "TTSPregenJob":
        """Create from dictionary (database row or API response).

        Handles both flat format (database rows) and nested format (API response
        with 'progress' key).
        """
        # Handle nested progress format from to_dict() API output
        progress = d.get("progress", {})
        total_items = progress.get("total", d.get("total_items", 0))
        completed_items = progress.get("completed", d.get("completed_items", 0))
        failed_items = progress.get("failed", d.get("failed_items", 0))
        current_item_index = progress.get("current_index", d.get("current_item_index", 0))
        current_item_text = progress.get("current_text", d.get("current_item_text"))

        return cls(
            id=UUID(d["id"]) if isinstance(d["id"], str) else d["id"],
            name=d["name"],
            job_type=d["job_type"],
            status=JobStatus(d["status"]),
            source_type=d["source_type"],
            source_id=d.get("source_id"),
            profile_id=UUID(d["profile_id"]) if d.get("profile_id") else None,
            tts_config=d.get("tts_config"),
            output_format=d.get("output_format", "wav"),
            normalize_volume=d.get("normalize_volume", False),
            output_dir=d.get("output_dir", ""),
            total_items=total_items,
            completed_items=completed_items,
            failed_items=failed_items,
            current_item_index=current_item_index,
            current_item_text=current_item_text,
            created_at=datetime.fromisoformat(d["created_at"]) if isinstance(d.get("created_at"), str) else d.get("created_at", _utc_now()),
            started_at=datetime.fromisoformat(d["started_at"]) if isinstance(d.get("started_at"), str) and d.get("started_at") else None,
            paused_at=datetime.fromisoformat(d["paused_at"]) if isinstance(d.get("paused_at"), str) and d.get("paused_at") else None,
            completed_at=datetime.fromisoformat(d["completed_at"]) if isinstance(d.get("completed_at"), str) and d.get("completed_at") else None,
            updated_at=datetime.fromisoformat(d["updated_at"]) if isinstance(d.get("updated_at"), str) else d.get("updated_at", _utc_now()),
            last_error=d.get("last_error"),
            consecutive_failures=d.get("consecutive_failures", 0),
        )

    @classmethod
    def create(
        cls,
        name: str,
        source_type: str,
        output_dir: str,
        profile_id: Optional[UUID] = None,
        tts_config: Optional[Dict[str, Any]] = None,
        **kwargs: Any,
    ) -> "TTSPregenJob":
        """Factory method to create a new job."""
        return cls(
            id=uuid4(),
            name=name,
            job_type="batch",
            status=JobStatus.PENDING,
            source_type=source_type,
            output_dir=output_dir,
            profile_id=profile_id,
            tts_config=tts_config,
            **kwargs,
        )


@dataclass
class TTSJobItem:
    """An individual item within a TTS generation job."""
    id: UUID
    job_id: UUID
    item_index: int

    text_content: str
    text_hash: str  # SHA-256 for dedup
    source_ref: Optional[str] = None  # question_id, segment_id, etc.

    status: ItemStatus = ItemStatus.PENDING
    attempt_count: int = 0

    # Result
    output_file: Optional[str] = None
    duration_seconds: Optional[float] = None
    file_size_bytes: Optional[int] = None
    sample_rate: Optional[int] = None

    # Error
    last_error: Optional[str] = None
    processing_started_at: Optional[datetime] = None
    processing_completed_at: Optional[datetime] = None

    @classmethod
    def hash_text(cls, text: str) -> str:
        """Generate SHA-256 hash of text."""
        return hashlib.sha256(text.encode()).hexdigest()

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "id": str(self.id),
            "job_id": str(self.job_id),
            "item_index": self.item_index,
            "text_content": self.text_content,
            "text_hash": self.text_hash,
            "source_ref": self.source_ref,
            "status": self.status.value,
            "attempt_count": self.attempt_count,
            "output_file": self.output_file,
            "duration_seconds": self.duration_seconds,
            "file_size_bytes": self.file_size_bytes,
            "sample_rate": self.sample_rate,
            "last_error": self.last_error,
            "processing_started_at": self.processing_started_at.isoformat() if self.processing_started_at else None,
            "processing_completed_at": self.processing_completed_at.isoformat() if self.processing_completed_at else None,
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "TTSJobItem":
        """Create from dictionary."""
        return cls(
            id=UUID(d["id"]) if isinstance(d["id"], str) else d["id"],
            job_id=UUID(d["job_id"]) if isinstance(d["job_id"], str) else d["job_id"],
            item_index=d["item_index"],
            text_content=d["text_content"],
            text_hash=d["text_hash"],
            source_ref=d.get("source_ref"),
            status=ItemStatus(d.get("status", "pending")),
            attempt_count=d.get("attempt_count", 0),
            output_file=d.get("output_file"),
            duration_seconds=d.get("duration_seconds"),
            file_size_bytes=d.get("file_size_bytes"),
            sample_rate=d.get("sample_rate"),
            last_error=d.get("last_error"),
            processing_started_at=datetime.fromisoformat(d["processing_started_at"]) if d.get("processing_started_at") else None,
            processing_completed_at=datetime.fromisoformat(d["processing_completed_at"]) if d.get("processing_completed_at") else None,
        )

    @classmethod
    def create(
        cls,
        job_id: UUID,
        item_index: int,
        text_content: str,
        source_ref: Optional[str] = None,
    ) -> "TTSJobItem":
        """Factory method to create a new item."""
        return cls(
            id=uuid4(),
            job_id=job_id,
            item_index=item_index,
            text_content=text_content,
            text_hash=cls.hash_text(text_content),
            source_ref=source_ref,
        )


@dataclass
class TTSComparisonSession:
    """A session for comparing multiple TTS configurations.

    Sessions contain samples (text) and configurations (TTS settings)
    to create a matrix of variants for A/B testing.
    """
    id: UUID
    name: str
    status: SessionStatus

    # Configuration stored as JSON
    config: Dict[str, Any]  # {samples: [...], configurations: [...]}

    description: Optional[str] = None
    created_at: datetime = field(default_factory=_utc_now)
    updated_at: datetime = field(default_factory=_utc_now)

    @property
    def sample_count(self) -> int:
        """Number of text samples in the session."""
        return len(self.config.get("samples", []))

    @property
    def config_count(self) -> int:
        """Number of TTS configurations in the session."""
        return len(self.config.get("configurations", []))

    @property
    def total_variants(self) -> int:
        """Total number of variants (samples x configurations)."""
        return self.sample_count * self.config_count

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "id": str(self.id),
            "name": self.name,
            "status": self.status.value,
            "description": self.description,
            "config": self.config,
            "sample_count": self.sample_count,
            "config_count": self.config_count,
            "total_variants": self.total_variants,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "TTSComparisonSession":
        """Create from dictionary."""
        return cls(
            id=UUID(d["id"]) if isinstance(d["id"], str) else d["id"],
            name=d["name"],
            status=SessionStatus(d.get("status", "draft")),
            description=d.get("description"),
            config=d.get("config", {}),
            created_at=datetime.fromisoformat(d["created_at"]) if isinstance(d.get("created_at"), str) else d.get("created_at", _utc_now()),
            updated_at=datetime.fromisoformat(d["updated_at"]) if isinstance(d.get("updated_at"), str) else d.get("updated_at", _utc_now()),
        )

    @classmethod
    def create(
        cls,
        name: str,
        samples: List[Dict[str, Any]],
        configurations: List[Dict[str, Any]],
        description: Optional[str] = None,
    ) -> "TTSComparisonSession":
        """Factory method to create a new session."""
        return cls(
            id=uuid4(),
            name=name,
            status=SessionStatus.DRAFT,
            description=description,
            config={
                "samples": samples,
                "configurations": configurations,
            },
        )


@dataclass
class TTSComparisonVariant:
    """A single audio variant in a comparison session.

    Represents one cell in the samples x configurations matrix.
    """
    id: UUID
    session_id: UUID
    sample_index: int
    config_index: int

    text_content: str
    tts_config: Dict[str, Any]

    status: VariantStatus = VariantStatus.PENDING

    # Result
    output_file: Optional[str] = None
    duration_seconds: Optional[float] = None
    last_error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "id": str(self.id),
            "session_id": str(self.session_id),
            "sample_index": self.sample_index,
            "config_index": self.config_index,
            "text_content": self.text_content,
            "tts_config": self.tts_config,
            "status": self.status.value,
            "output_file": self.output_file,
            "duration_seconds": self.duration_seconds,
            "last_error": self.last_error,
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "TTSComparisonVariant":
        """Create from dictionary."""
        return cls(
            id=UUID(d["id"]) if isinstance(d["id"], str) else d["id"],
            session_id=UUID(d["session_id"]) if isinstance(d["session_id"], str) else d["session_id"],
            sample_index=d["sample_index"],
            config_index=d["config_index"],
            text_content=d["text_content"],
            tts_config=d["tts_config"],
            status=VariantStatus(d.get("status", "pending")),
            output_file=d.get("output_file"),
            duration_seconds=d.get("duration_seconds"),
            last_error=d.get("last_error"),
        )

    @classmethod
    def create(
        cls,
        session_id: UUID,
        sample_index: int,
        config_index: int,
        text_content: str,
        tts_config: Dict[str, Any],
    ) -> "TTSComparisonVariant":
        """Factory method to create a new variant."""
        return cls(
            id=uuid4(),
            session_id=session_id,
            sample_index=sample_index,
            config_index=config_index,
            text_content=text_content,
            tts_config=tts_config,
        )


@dataclass
class TTSComparisonRating:
    """A user rating for a comparison variant."""
    id: UUID
    variant_id: UUID
    rating: Optional[int] = None  # 1-5 stars
    notes: Optional[str] = None
    rated_at: datetime = field(default_factory=_utc_now)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "id": str(self.id),
            "variant_id": str(self.variant_id),
            "rating": self.rating,
            "notes": self.notes,
            "rated_at": self.rated_at.isoformat(),
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "TTSComparisonRating":
        """Create from dictionary."""
        return cls(
            id=UUID(d["id"]) if isinstance(d["id"], str) else d["id"],
            variant_id=UUID(d["variant_id"]) if isinstance(d["variant_id"], str) else d["variant_id"],
            rating=d.get("rating"),
            notes=d.get("notes"),
            rated_at=datetime.fromisoformat(d["rated_at"]) if isinstance(d.get("rated_at"), str) else d.get("rated_at", _utc_now()),
        )

    @classmethod
    def create(
        cls,
        variant_id: UUID,
        rating: Optional[int] = None,
        notes: Optional[str] = None,
    ) -> "TTSComparisonRating":
        """Factory method to create a new rating."""
        return cls(
            id=uuid4(),
            variant_id=variant_id,
            rating=rating,
            notes=notes,
        )
