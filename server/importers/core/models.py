"""
Data models for the curriculum import system.

These models are used throughout the import pipeline for:
- Source catalog information
- Course metadata
- Import configuration and progress tracking
- License preservation (CRITICAL)
"""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional


# =============================================================================
# License Models (CRITICAL - Must preserve licensing information)
# =============================================================================

@dataclass
class LicenseInfo:
    """
    License information that MUST be preserved for all imported content.

    This is critical for legal compliance. Every imported curriculum
    must include complete license information.
    """
    type: str                      # e.g., "CC-BY-NC-SA-4.0"
    name: str                      # Full license name
    url: str                       # License URL
    permissions: List[str]         # e.g., ["share", "adapt"]
    conditions: List[str]          # e.g., ["attribution", "noncommercial"]
    attribution_required: bool = True
    attribution_format: str = ""   # Required attribution text
    holder_name: str = ""          # Copyright holder
    holder_url: str = ""           # Holder's website
    restrictions: List[str] = field(default_factory=list)  # Special restrictions

    def to_dict(self) -> Dict[str, Any]:
        return {
            "type": self.type,
            "name": self.name,
            "url": self.url,
            "permissions": self.permissions,
            "conditions": self.conditions,
            "attributionRequired": self.attribution_required,
            "attributionFormat": self.attribution_format,
            "holder": {
                "name": self.holder_name,
                "url": self.holder_url,
            },
            "restrictions": self.restrictions,
        }


# =============================================================================
# Source Models
# =============================================================================

@dataclass
class CurriculumSource:
    """
    A configured curriculum source (e.g., MIT OCW, Stanford SEE).
    """
    id: str                        # e.g., "mit_ocw"
    name: str                      # Display name
    description: str               # Short description
    logo_url: Optional[str] = None # Source logo
    license: Optional[LicenseInfo] = None  # Default license
    course_count: str = "0"        # Approximate count
    features: List[str] = field(default_factory=list)  # Available features
    status: str = "active"         # "active", "coming_soon", "maintenance"
    base_url: str = ""             # Source website URL

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "logoUrl": self.logo_url,
            "license": self.license.to_dict() if self.license else None,
            "courseCount": self.course_count,
            "features": self.features,
            "status": self.status,
            "baseUrl": self.base_url,
        }


@dataclass
class CourseFeature:
    """A feature available in a course (video, transcripts, etc.)."""
    type: str                      # e.g., "video", "transcript"
    count: Optional[int] = None    # Number of items
    available: bool = True

    def to_dict(self) -> Dict[str, Any]:
        return {
            "type": self.type,
            "count": self.count,
            "available": self.available,
        }


@dataclass
class CourseCatalogEntry:
    """
    A course entry in a source's catalog (minimal info for listing).
    """
    id: str                        # Source-specific ID
    source_id: str                 # Parent source
    title: str
    instructors: List[str]
    description: str
    level: str = "intermediate"    # introductory, intermediate, advanced
    department: Optional[str] = None
    semester: Optional[str] = None
    features: List[CourseFeature] = field(default_factory=list)
    license: Optional[LicenseInfo] = None
    thumbnail_url: Optional[str] = None
    keywords: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "sourceId": self.source_id,
            "title": self.title,
            "instructors": self.instructors,
            "description": self.description,
            "level": self.level,
            "department": self.department,
            "semester": self.semester,
            "features": [f.to_dict() for f in self.features],
            "license": self.license.to_dict() if self.license else None,
            "thumbnailUrl": self.thumbnail_url,
            "keywords": self.keywords,
        }


# =============================================================================
# Normalized Content Structure Models (for Generic Plugin UI)
# =============================================================================

@dataclass
class ContentTopic:
    """
    A normalized topic within a content unit.

    This represents the smallest selectable content item (lesson, lecture,
    section, video, etc.) in a normalized format that works with any plugin.
    """
    id: str
    title: str
    number: int = 0
    duration: Optional[str] = None  # e.g., "1:15:00"
    has_video: bool = False
    has_transcript: bool = False
    has_practice: bool = False
    description: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "number": self.number,
            "duration": self.duration,
            "hasVideo": self.has_video,
            "hasTranscript": self.has_transcript,
            "hasPractice": self.has_practice,
            "description": self.description,
        }


@dataclass
class ContentUnit:
    """
    A normalized content unit (chapter, module, unit, etc.).

    Contains a list of topics. For flat structures (like MIT OCW lectures),
    the plugin can return a single unit containing all lectures as topics.
    """
    id: str
    title: str
    number: int = 0
    description: Optional[str] = None
    topics: List[ContentTopic] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "number": self.number,
            "description": self.description,
            "topics": [t.to_dict() for t in self.topics],
        }


@dataclass
class ContentStructure:
    """
    Normalized content structure with source terminology hints.

    This allows the UI to display content generically while preserving
    source-specific terminology for user familiarity.

    Example:
        unitLabel="Chapter", topicLabel="Lesson" -> "Units (Chapters)" in UI
        unitLabel="Lecture", topicLabel="Lecture" -> flat structure (MIT OCW)
    """
    # Source terminology hints
    unit_label: str = "Unit"           # What source calls units (Chapter, Module, etc.)
    topic_label: str = "Topic"         # What source calls topics (Lesson, Lecture, etc.)

    # Whether structure is flat (no hierarchy) or nested
    is_flat: bool = False              # True for flat lecture lists like MIT OCW

    # The content hierarchy
    units: List[ContentUnit] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "unitLabel": self.unit_label,
            "topicLabel": self.topic_label,
            "isFlat": self.is_flat,
            "units": [u.to_dict() for u in self.units],
        }


@dataclass
class NormalizedCourseDetail:
    """
    Fully normalized course detail for generic plugin UI.

    This extends the basic course info with normalized content structure
    that works with ANY plugin without source-specific UI code.
    """
    # Basic info
    id: str
    source_id: str
    title: str
    description: str

    # Metadata (plugin provides what it has)
    instructors: List[str] = field(default_factory=list)
    level: str = "intermediate"        # normalized: introductory, intermediate, advanced
    level_label: str = ""              # display-friendly, e.g., "Middle School"
    department: Optional[str] = None
    semester: Optional[str] = None
    keywords: List[str] = field(default_factory=list)
    thumbnail_url: Optional[str] = None

    # License (standard format)
    license: Optional[LicenseInfo] = None

    # Features (standard keys)
    features: List[CourseFeature] = field(default_factory=list)

    # NORMALIZED content structure with source terminology
    content_structure: Optional[ContentStructure] = None

    # Additional materials
    assignments: List["AssignmentInfo"] = field(default_factory=list)
    exams: List["ExamInfo"] = field(default_factory=list)
    syllabus: Optional[str] = None
    prerequisites: List[str] = field(default_factory=list)

    # Import info
    estimated_import_time: str = "Unknown"
    estimated_output_size: str = "Unknown"

    # Source links
    source_url: Optional[str] = None
    download_url: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "sourceId": self.source_id,
            "title": self.title,
            "description": self.description,
            "instructors": self.instructors,
            "level": self.level,
            "levelLabel": self.level_label or self.level.title(),
            "department": self.department,
            "semester": self.semester,
            "keywords": self.keywords,
            "thumbnailUrl": self.thumbnail_url,
            "license": self.license.to_dict() if self.license else None,
            "features": [f.to_dict() for f in self.features],
            "contentStructure": self.content_structure.to_dict() if self.content_structure else None,
            "assignments": [a.to_dict() for a in self.assignments],
            "exams": [e.to_dict() for e in self.exams],
            "syllabus": self.syllabus,
            "prerequisites": self.prerequisites,
            "estimatedImportTime": self.estimated_import_time,
            "estimatedOutputSize": self.estimated_output_size,
            "sourceUrl": self.source_url,
            "downloadUrl": self.download_url,
        }


# =============================================================================
# Course Detail Models (Legacy, kept for compatibility)
# =============================================================================

@dataclass
class LectureInfo:
    """Information about a single lecture."""
    id: str
    number: int
    title: str
    duration: Optional[str] = None  # e.g., "1:15:00"
    has_video: bool = False
    has_transcript: bool = False
    has_notes: bool = False
    video_url: Optional[str] = None
    transcript_url: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "number": self.number,
            "title": self.title,
            "duration": self.duration,
            "hasVideo": self.has_video,
            "hasTranscript": self.has_transcript,
            "hasNotes": self.has_notes,
            "videoUrl": self.video_url,
            "transcriptUrl": self.transcript_url,
        }


@dataclass
class AssignmentInfo:
    """Information about an assignment/problem set."""
    id: str
    title: str
    has_solutions: bool = False
    description: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "hasSolutions": self.has_solutions,
            "description": self.description,
        }


@dataclass
class ExamInfo:
    """Information about an exam."""
    id: str
    title: str
    exam_type: str = "exam"        # quiz, midterm, final
    has_solutions: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "type": self.exam_type,
            "hasSolutions": self.has_solutions,
        }


@dataclass
class CourseDetail(CourseCatalogEntry):
    """
    Full course details (extended from catalog entry).
    Used for the course detail view before import.
    """
    syllabus: Optional[str] = None
    prerequisites: List[str] = field(default_factory=list)
    lectures: List[LectureInfo] = field(default_factory=list)
    assignments: List[AssignmentInfo] = field(default_factory=list)
    exams: List[ExamInfo] = field(default_factory=list)
    estimated_import_time: str = "Unknown"
    estimated_output_size: str = "Unknown"
    download_url: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        base = super().to_dict()
        base.update({
            "syllabus": self.syllabus,
            "prerequisites": self.prerequisites,
            "lectures": [l.to_dict() for l in self.lectures],
            "assignments": [a.to_dict() for a in self.assignments],
            "exams": [e.to_dict() for e in self.exams],
            "estimatedImportTime": self.estimated_import_time,
            "estimatedOutputSize": self.estimated_output_size,
        })
        return base


# =============================================================================
# Import Configuration
# =============================================================================

@dataclass
class ImportConfig:
    """
    Configuration for an import job.
    Specifies what to import and how to process it.
    """
    source_id: str
    course_id: str
    output_name: str

    # Selective import - which lectures to include (empty = all)
    selected_lectures: List[str] = field(default_factory=list)

    # Content selection
    include_transcripts: bool = True
    include_lecture_notes: bool = True
    include_assignments: bool = True
    include_exams: bool = True
    include_videos: bool = False   # Usually false (too large)

    # AI Enrichment options
    generate_objectives: bool = True
    create_checkpoints: bool = True
    generate_spoken_text: bool = True
    build_knowledge_graph: bool = True
    generate_practice_problems: bool = False
    generate_media: bool = True  # Generate maps, diagrams, formula fallbacks

    def to_dict(self) -> Dict[str, Any]:
        return {
            "sourceId": self.source_id,
            "courseId": self.course_id,
            "outputName": self.output_name,
            "selectedLectures": self.selected_lectures,
            "includeTranscripts": self.include_transcripts,
            "includeLectureNotes": self.include_lecture_notes,
            "includeAssignments": self.include_assignments,
            "includeExams": self.include_exams,
            "includeVideos": self.include_videos,
            "generateObjectives": self.generate_objectives,
            "createCheckpoints": self.create_checkpoints,
            "generateSpokenText": self.generate_spoken_text,
            "buildKnowledgeGraph": self.build_knowledge_graph,
            "generatePracticeProblems": self.generate_practice_problems,
            "generateMedia": self.generate_media,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ImportConfig":
        return cls(
            source_id=data["sourceId"],
            course_id=data["courseId"],
            output_name=data["outputName"],
            selected_lectures=data.get("selectedLectures", []),
            include_transcripts=data.get("includeTranscripts", True),
            include_lecture_notes=data.get("includeLectureNotes", True),
            include_assignments=data.get("includeAssignments", True),
            include_exams=data.get("includeExams", True),
            include_videos=data.get("includeVideos", False),
            generate_objectives=data.get("generateObjectives", True),
            create_checkpoints=data.get("createCheckpoints", True),
            generate_spoken_text=data.get("generateSpokenText", True),
            build_knowledge_graph=data.get("buildKnowledgeGraph", True),
            generate_practice_problems=data.get("generatePracticeProblems", False),
            generate_media=data.get("generateMedia", True),
        )


# =============================================================================
# Import Progress Tracking
# =============================================================================

class ImportStatus(Enum):
    """Status of an import job."""
    QUEUED = "queued"
    DOWNLOADING = "downloading"
    VALIDATING = "validating"
    EXTRACTING = "extracting"
    ENRICHING = "enriching"
    GENERATING = "generating"
    COMPLETE = "complete"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class ImportStage:
    """Progress information for a single stage."""
    id: str
    name: str
    status: str = "pending"        # pending, running, complete, failed, skipped
    progress: float = 0.0          # 0-100
    details: Optional[str] = None
    substages: List["ImportStage"] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "status": self.status,
            "progress": self.progress,
            "details": self.details,
            "substages": [s.to_dict() for s in self.substages],
        }


@dataclass
class ImportLogEntry:
    """A log entry during import."""
    timestamp: str
    level: str                     # info, warning, error
    message: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "timestamp": self.timestamp,
            "level": self.level,
            "message": self.message,
        }


@dataclass
class ImportResult:
    """Result of a successful import."""
    curriculum_id: str
    title: str
    topic_count: int
    assessment_count: int
    output_path: str
    output_size: str
    license: LicenseInfo

    def to_dict(self) -> Dict[str, Any]:
        return {
            "curriculumId": self.curriculum_id,
            "title": self.title,
            "topicCount": self.topic_count,
            "assessmentCount": self.assessment_count,
            "outputPath": self.output_path,
            "outputSize": self.output_size,
            "license": self.license.to_dict(),
        }


@dataclass
class ImportProgress:
    """
    Full progress information for an import job.
    Used for real-time progress tracking.
    """
    id: str
    config: ImportConfig
    status: ImportStatus = ImportStatus.QUEUED
    overall_progress: float = 0.0  # 0-100
    current_stage: str = ""
    current_activity: str = ""
    stages: List[ImportStage] = field(default_factory=list)
    log: List[ImportLogEntry] = field(default_factory=list)
    result: Optional[ImportResult] = None
    error: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "config": self.config.to_dict(),
            "status": self.status.value,
            "overallProgress": self.overall_progress,
            "currentStage": self.current_stage,
            "currentActivity": self.current_activity,
            "stages": [s.to_dict() for s in self.stages],
            "log": [l.to_dict() for l in self.log],
            "result": self.result.to_dict() if self.result else None,
            "error": self.error,
            "createdAt": self.created_at.isoformat(),
            "updatedAt": self.updated_at.isoformat(),
        }

    def add_log(self, level: str, message: str):
        """Add a log entry."""
        entry = ImportLogEntry(
            timestamp=datetime.utcnow().isoformat(),
            level=level,
            message=message,
        )
        self.log.append(entry)
        self.updated_at = datetime.utcnow()

    def update_stage(self, stage_id: str, status: str, progress: float = None, details: str = None):
        """Update a stage's status."""
        for stage in self.stages:
            if stage.id == stage_id:
                stage.status = status
                if progress is not None:
                    stage.progress = progress
                if details is not None:
                    stage.details = details
                break
            # Check substages
            for substage in stage.substages:
                if substage.id == stage_id:
                    substage.status = status
                    if progress is not None:
                        substage.progress = progress
                    if details is not None:
                        substage.details = details
                    break
        self.updated_at = datetime.utcnow()
