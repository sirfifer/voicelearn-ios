"""
Core importer components: models, base classes, orchestration, plugins.

This module provides both the legacy handler-based architecture and the
new industry-standard plugin architecture based on pluggy.

For new code, prefer the plugin architecture:
    from importers.core import PluginManager, BaseImporterPlugin, hookimpl

For legacy compatibility:
    from importers.core import CurriculumSourceHandler, SourceRegistry
"""

from .models import (
    LicenseInfo,
    CurriculumSource,
    CourseFeature,
    CourseCatalogEntry,
    CourseDetail,
    LectureInfo,
    AssignmentInfo,
    ExamInfo,
    ImportConfig,
    ImportStage,
    ImportLogEntry,
    ImportProgress,
    ImportResult,
    ImportStatus,
)
from .base import CurriculumSourceHandler, LicenseValidationResult, ValidationResult
from .orchestrator import ImportOrchestrator
from .registry import SourceRegistry, discover_handlers, init_plugin_system

# Plugin architecture components
from .plugin import (
    # Markers
    hookspec,
    hookimpl,
    # Types
    PluginType,
    PluginMetadata,
    PluginConfig,
    # Protocols
    ImporterPlugin,
    ImporterHookSpec,
    # Base classes
    BaseImporterPlugin,
    # Manager
    PluginManager,
    PluginRegistry,
    get_plugin_manager,
    reset_plugin_manager,
    PROJECT_NAME,
)
from .adapter import LegacySourceAdapter, wrap_legacy_handlers

__all__ = [
    # Models
    "LicenseInfo",
    "CurriculumSource",
    "CourseFeature",
    "CourseCatalogEntry",
    "CourseDetail",
    "LectureInfo",
    "AssignmentInfo",
    "ExamInfo",
    "ImportConfig",
    "ImportStage",
    "ImportLogEntry",
    "ImportProgress",
    "ImportResult",
    "ImportStatus",
    # Legacy Classes
    "CurriculumSourceHandler",
    "LicenseValidationResult",
    "ValidationResult",
    "ImportOrchestrator",
    "SourceRegistry",
    "discover_handlers",
    # Plugin Architecture
    "hookspec",
    "hookimpl",
    "PluginType",
    "PluginMetadata",
    "PluginConfig",
    "ImporterPlugin",
    "ImporterHookSpec",
    "BaseImporterPlugin",
    "PluginManager",
    "PluginRegistry",
    "get_plugin_manager",
    "reset_plugin_manager",
    "init_plugin_system",
    "PROJECT_NAME",
    # Adapters
    "LegacySourceAdapter",
    "wrap_legacy_handlers",
]
