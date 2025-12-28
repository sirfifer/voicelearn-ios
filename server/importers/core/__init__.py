"""
Core importer components: models, base classes, orchestration, plugins.

This module provides the plugin architecture for curriculum importers.
Plugins are auto-discovered from the plugins/ folder but must be enabled
through the Plugin Manager in the Management Console.

Usage:
    from importers.core import PluginDiscovery, SourceRegistry

    # Discover available plugins
    discovery = get_plugin_discovery()
    plugins = discovery.discover_all()

    # Access enabled plugins
    sources = SourceRegistry.get_all_sources()
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

# Plugin discovery components
from .discovery import (
    DiscoveredPlugin,
    PluginState,
    PluginDiscovery,
    get_plugin_discovery,
    reset_plugin_discovery,
)

# Plugin architecture components (kept for compatibility but simplified)
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
    # Base Classes
    "CurriculumSourceHandler",
    "LicenseValidationResult",
    "ValidationResult",
    "ImportOrchestrator",
    "SourceRegistry",
    "discover_handlers",
    # Plugin Discovery
    "DiscoveredPlugin",
    "PluginState",
    "PluginDiscovery",
    "get_plugin_discovery",
    "reset_plugin_discovery",
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
]
