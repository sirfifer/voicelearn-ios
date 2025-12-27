"""
Plugin Architecture for Curriculum Importers.

This module implements an industry-standard plugin architecture using:
- Pluggy for hook specifications and implementations
- Setuptools Entry Points for external plugin discovery
- Local discovery for built-in plugins

Based on best practices from:
- pytest (pluggy)
- OpenStack (stevedore)
- Python Packaging Authority guidelines

References:
- https://pluggy.readthedocs.io/
- https://packaging.python.org/en/latest/guides/creating-and-discovering-plugins/
- https://pypi.org/project/pluggy/
"""

from __future__ import annotations

import asyncio
import importlib.metadata
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import (
    TYPE_CHECKING,
    Any,
    Callable,
    Dict,
    List,
    Optional,
    Protocol,
    Tuple,
    Type,
    TypeVar,
    runtime_checkable,
)

import pluggy

if TYPE_CHECKING:
    from .models import (
        CourseCatalogEntry,
        CourseDetail,
        CurriculumSource,
        ImportConfig,
        LicenseInfo,
    )
    from .base import LicenseValidationResult, ValidationResult

logger = logging.getLogger(__name__)

# Plugin project name - used for hook markers and entry point discovery
PROJECT_NAME = "unamentis.importers"

# Create hook specification and implementation markers
hookspec = pluggy.HookspecMarker(PROJECT_NAME)
hookimpl = pluggy.HookimplMarker(PROJECT_NAME)


class PluginType(Enum):
    """Types of plugins supported by the importer framework."""

    SOURCE = "source"           # Curriculum source handlers (MIT OCW, etc.)
    PARSER = "parser"           # Content parsers (PDF, HTML, etc.)
    ENRICHER = "enricher"       # AI enrichment plugins
    EXPORTER = "exporter"       # Output format exporters
    VALIDATOR = "validator"     # Content validators


@dataclass
class PluginMetadata:
    """Metadata about a registered plugin."""

    name: str
    version: str
    description: str
    plugin_type: PluginType
    author: Optional[str] = None
    url: Optional[str] = None
    requires: List[str] = field(default_factory=list)
    provides: List[str] = field(default_factory=list)
    entry_point: Optional[str] = None  # e.g., "unamentis.importers.sources"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            "name": self.name,
            "version": self.version,
            "description": self.description,
            "plugin_type": self.plugin_type.value,
            "author": self.author,
            "url": self.url,
            "requires": self.requires,
            "provides": self.provides,
            "entry_point": self.entry_point,
        }


@dataclass
class PluginConfig:
    """Configuration for a plugin instance."""

    enabled: bool = True
    priority: int = 100  # Lower = higher priority
    settings: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "PluginConfig":
        """Create from dictionary."""
        return cls(
            enabled=data.get("enabled", True),
            priority=data.get("priority", 100),
            settings=data.get("settings", {}),
        )


class ImporterHookSpec:
    """
    Hook specifications for curriculum source plugins.

    These define the contract that source plugins must implement.
    The @hookspec decorator marks methods as hook specifications.
    """

    # =========================================================================
    # Lifecycle Hooks
    # =========================================================================

    @hookspec
    def plugin_registered(self, plugin: "ImporterPlugin", manager: "PluginManager") -> None:
        """
        Called when a plugin is registered with the manager.

        Use this for one-time initialization that requires access to
        the plugin manager.

        Args:
            plugin: The plugin instance being registered
            manager: The plugin manager
        """
        pass

    @hookspec
    def plugin_unregistered(self, plugin: "ImporterPlugin") -> None:
        """
        Called when a plugin is unregistered.

        Use this for cleanup before the plugin is removed.

        Args:
            plugin: The plugin instance being unregistered
        """
        pass

    @hookspec
    def configure(self, config: PluginConfig) -> None:
        """
        Called to configure the plugin with runtime settings.

        Args:
            config: Plugin configuration
        """
        pass

    @hookspec
    def validate_config(self, config: PluginConfig) -> List[str]:
        """
        Validate plugin configuration.

        Args:
            config: Configuration to validate

        Returns:
            List of validation error messages (empty if valid)
        """
        pass

    # =========================================================================
    # Source Plugin Hooks (for curriculum sources)
    # =========================================================================

    @hookspec(firstresult=True)
    def get_source_info(self) -> Optional["CurriculumSource"]:
        """
        Get information about this curriculum source.

        Returns:
            CurriculumSource with source metadata, or None
        """
        pass

    @hookspec(firstresult=True)
    def get_default_license(self) -> Optional["LicenseInfo"]:
        """
        Get the default license for content from this source.

        Returns:
            LicenseInfo for the default license, or None
        """
        pass

    @hookspec(firstresult=True)
    async def get_course_catalog(
        self,
        page: int,
        page_size: int,
        filters: Optional[Dict[str, Any]],
        search: Optional[str],
    ) -> Optional[Tuple[List["CourseCatalogEntry"], int, Dict[str, List[str]]]]:
        """
        Get paginated course catalog.

        Args:
            page: Page number (1-indexed)
            page_size: Items per page
            filters: Optional filters
            search: Optional search query

        Returns:
            Tuple of (entries, total_count, filter_options) or None
        """
        pass

    @hookspec(firstresult=True)
    async def get_course_detail(self, course_id: str) -> Optional["CourseDetail"]:
        """
        Get detailed information about a specific course.

        Args:
            course_id: Course identifier

        Returns:
            CourseDetail or None if not found
        """
        pass

    @hookspec(firstresult=True)
    async def download_course(
        self,
        course_id: str,
        output_dir: Path,
        progress_callback: Optional[Callable[[float, str], None]],
    ) -> Optional[Path]:
        """
        Download course content.

        Args:
            course_id: Course to download
            output_dir: Where to save content
            progress_callback: Progress reporter

        Returns:
            Path to downloaded content, or None
        """
        pass

    @hookspec(firstresult=True)
    def validate_license(self, course_id: str) -> Optional["LicenseValidationResult"]:
        """
        Validate license for importing a course.

        Args:
            course_id: Course to validate

        Returns:
            LicenseValidationResult or None
        """
        pass

    # =========================================================================
    # Parser Plugin Hooks
    # =========================================================================

    @hookspec
    def get_supported_formats(self) -> List[str]:
        """
        Get list of content formats this parser supports.

        Returns:
            List of format identifiers (e.g., ["pdf", "pdf/ocw"])
        """
        pass

    @hookspec(firstresult=True)
    async def parse_content(
        self,
        content_path: Path,
        format_hint: Optional[str],
    ) -> Optional[Dict[str, Any]]:
        """
        Parse content from a file.

        Args:
            content_path: Path to content file
            format_hint: Hint about the content format

        Returns:
            Parsed content as dictionary, or None
        """
        pass

    # =========================================================================
    # Enrichment Plugin Hooks
    # =========================================================================

    @hookspec
    async def enrich_content(
        self,
        content: Dict[str, Any],
        config: "ImportConfig",
    ) -> Dict[str, Any]:
        """
        Enrich content with AI-generated additions.

        Args:
            content: Content to enrich
            config: Import configuration

        Returns:
            Enriched content
        """
        pass

    @hookspec
    def get_enrichment_stages(self) -> List[str]:
        """
        Get list of enrichment stages this plugin provides.

        Returns:
            List of stage names
        """
        pass

    # =========================================================================
    # Validation Hooks
    # =========================================================================

    @hookspec
    async def validate_content(
        self,
        content: Dict[str, Any],
        content_type: str,
    ) -> "ValidationResult":
        """
        Validate content.

        Args:
            content: Content to validate
            content_type: Type of content

        Returns:
            ValidationResult with errors/warnings
        """
        pass

    # =========================================================================
    # Export Hooks
    # =========================================================================

    @hookspec
    def get_export_formats(self) -> List[str]:
        """
        Get list of export formats this exporter supports.

        Returns:
            List of format identifiers (e.g., ["umlcf", "scorm"])
        """
        pass

    @hookspec(firstresult=True)
    async def export_content(
        self,
        content: Dict[str, Any],
        output_path: Path,
        format_id: str,
    ) -> Optional[Path]:
        """
        Export content to specified format.

        Args:
            content: Content to export
            output_path: Output directory
            format_id: Export format

        Returns:
            Path to exported file(s), or None
        """
        pass


@runtime_checkable
class ImporterPlugin(Protocol):
    """
    Protocol defining the interface for importer plugins.

    Plugins must implement this protocol to be registered with
    the plugin manager.
    """

    @property
    def plugin_id(self) -> str:
        """Unique identifier for this plugin."""
        ...

    @property
    def plugin_type(self) -> PluginType:
        """Type of plugin."""
        ...

    @property
    def metadata(self) -> PluginMetadata:
        """Plugin metadata."""
        ...

    def get_hookimpl(self) -> object:
        """
        Get the object containing hook implementations.

        This can return self if the plugin class has @hookimpl
        decorated methods, or a separate implementation object.
        """
        ...


class BaseImporterPlugin(ABC):
    """
    Base class for importer plugins.

    Provides common functionality and enforces the plugin contract.
    Extend this class to create a new plugin.

    Example:
        @PluginRegistry.register
        class MySourcePlugin(BaseImporterPlugin):
            plugin_id = "my_source"
            plugin_type = PluginType.SOURCE

            @property
            def metadata(self) -> PluginMetadata:
                return PluginMetadata(
                    name="My Source",
                    version="1.0.0",
                    description="Import from My Source",
                    plugin_type=PluginType.SOURCE,
                )

            @hookimpl
            def get_source_info(self) -> CurriculumSource:
                return CurriculumSource(...)
    """

    _config: Optional[PluginConfig] = None

    @property
    @abstractmethod
    def plugin_id(self) -> str:
        """Unique identifier for this plugin (e.g., 'mit_ocw')."""
        pass

    @property
    @abstractmethod
    def plugin_type(self) -> PluginType:
        """Type of this plugin."""
        pass

    @property
    @abstractmethod
    def metadata(self) -> PluginMetadata:
        """Plugin metadata."""
        pass

    def get_hookimpl(self) -> object:
        """Return self as the hook implementation object."""
        return self

    @property
    def config(self) -> Optional[PluginConfig]:
        """Current plugin configuration."""
        return self._config

    @hookimpl
    def configure(self, config: PluginConfig) -> None:
        """Store configuration."""
        self._config = config

    @hookimpl
    def validate_config(self, config: PluginConfig) -> List[str]:
        """Default config validation (override for custom validation)."""
        return []

    @hookimpl
    def plugin_registered(self, plugin: "ImporterPlugin", manager: "PluginManager") -> None:
        """Called when registered. Override for custom initialization."""
        pass

    @hookimpl
    def plugin_unregistered(self, plugin: "ImporterPlugin") -> None:
        """Called when unregistered. Override for cleanup."""
        pass

    def get_config_setting(self, key: str, default: Any = None) -> Any:
        """Get a configuration setting."""
        if self._config is None:
            return default
        return self._config.settings.get(key, default)


class PluginManager:
    """
    Central manager for all importer plugins.

    Handles:
    - Plugin discovery (built-in and entry points)
    - Plugin registration and lifecycle
    - Hook invocation
    - Configuration management

    Example:
        # Initialize manager
        manager = PluginManager()

        # Discover and load plugins
        manager.discover_plugins()

        # Get a specific source plugin
        mit_plugin = manager.get_source("mit_ocw")

        # Call hooks
        catalog = await manager.hook.get_course_catalog(
            page=1, page_size=20, filters=None, search=None
        )
    """

    # Entry point group names for plugin discovery
    ENTRY_POINT_SOURCES = f"{PROJECT_NAME}.sources"
    ENTRY_POINT_PARSERS = f"{PROJECT_NAME}.parsers"
    ENTRY_POINT_ENRICHERS = f"{PROJECT_NAME}.enrichers"
    ENTRY_POINT_EXPORTERS = f"{PROJECT_NAME}.exporters"
    ENTRY_POINT_VALIDATORS = f"{PROJECT_NAME}.validators"

    def __init__(self) -> None:
        """Initialize the plugin manager."""
        self._pm = pluggy.PluginManager(PROJECT_NAME)
        self._pm.add_hookspecs(ImporterHookSpec)

        # Plugin registries by type
        self._plugins: Dict[str, ImporterPlugin] = {}
        self._sources: Dict[str, ImporterPlugin] = {}
        self._parsers: Dict[str, ImporterPlugin] = {}
        self._enrichers: Dict[str, ImporterPlugin] = {}
        self._exporters: Dict[str, ImporterPlugin] = {}
        self._validators: Dict[str, ImporterPlugin] = {}

        # Configuration
        self._configs: Dict[str, PluginConfig] = {}

        logger.info("PluginManager initialized")

    @property
    def hook(self) -> Any:
        """Access the pluggy hook caller."""
        return self._pm.hook

    def register(self, plugin: ImporterPlugin, config: Optional[PluginConfig] = None) -> None:
        """
        Register a plugin with the manager.

        Args:
            plugin: Plugin instance to register
            config: Optional configuration for the plugin
        """
        plugin_id = plugin.plugin_id

        if plugin_id in self._plugins:
            logger.warning(f"Plugin '{plugin_id}' already registered, skipping")
            return

        # Store plugin
        self._plugins[plugin_id] = plugin

        # Store in type-specific registry
        type_registry = self._get_type_registry(plugin.plugin_type)
        type_registry[plugin_id] = plugin

        # Register hook implementation
        hookimpl_obj = plugin.get_hookimpl()
        self._pm.register(hookimpl_obj, name=plugin_id)

        # Configure plugin
        if config:
            self._configs[plugin_id] = config
            self.hook.configure(config=config)

        # Notify plugin of registration
        self.hook.plugin_registered(plugin=plugin, manager=self)

        logger.info(
            f"Registered plugin: {plugin_id} "
            f"(type={plugin.plugin_type.value}, version={plugin.metadata.version})"
        )

    def unregister(self, plugin_id: str) -> bool:
        """
        Unregister a plugin.

        Args:
            plugin_id: ID of plugin to unregister

        Returns:
            True if unregistered, False if not found
        """
        if plugin_id not in self._plugins:
            return False

        plugin = self._plugins[plugin_id]

        # Notify plugin
        self.hook.plugin_unregistered(plugin=plugin)

        # Unregister from pluggy
        hookimpl_obj = plugin.get_hookimpl()
        self._pm.unregister(hookimpl_obj, name=plugin_id)

        # Remove from registries
        del self._plugins[plugin_id]
        type_registry = self._get_type_registry(plugin.plugin_type)
        del type_registry[plugin_id]

        if plugin_id in self._configs:
            del self._configs[plugin_id]

        logger.info(f"Unregistered plugin: {plugin_id}")
        return True

    def _get_type_registry(self, plugin_type: PluginType) -> Dict[str, ImporterPlugin]:
        """Get the registry for a specific plugin type."""
        registries = {
            PluginType.SOURCE: self._sources,
            PluginType.PARSER: self._parsers,
            PluginType.ENRICHER: self._enrichers,
            PluginType.EXPORTER: self._exporters,
            PluginType.VALIDATOR: self._validators,
        }
        return registries[plugin_type]

    def get_plugin(self, plugin_id: str) -> Optional[ImporterPlugin]:
        """Get a plugin by ID."""
        return self._plugins.get(plugin_id)

    def get_source(self, source_id: str) -> Optional[ImporterPlugin]:
        """Get a source plugin by ID."""
        return self._sources.get(source_id)

    def get_parser(self, parser_id: str) -> Optional[ImporterPlugin]:
        """Get a parser plugin by ID."""
        return self._parsers.get(parser_id)

    def get_enricher(self, enricher_id: str) -> Optional[ImporterPlugin]:
        """Get an enricher plugin by ID."""
        return self._enrichers.get(enricher_id)

    def get_exporter(self, exporter_id: str) -> Optional[ImporterPlugin]:
        """Get an exporter plugin by ID."""
        return self._exporters.get(exporter_id)

    def get_validator(self, validator_id: str) -> Optional[ImporterPlugin]:
        """Get a validator plugin by ID."""
        return self._validators.get(validator_id)

    def list_plugins(self, plugin_type: Optional[PluginType] = None) -> List[ImporterPlugin]:
        """
        List registered plugins.

        Args:
            plugin_type: Optional filter by type

        Returns:
            List of plugins
        """
        if plugin_type is None:
            return list(self._plugins.values())
        return list(self._get_type_registry(plugin_type).values())

    def list_sources(self) -> List[ImporterPlugin]:
        """List all source plugins."""
        return list(self._sources.values())

    def get_plugin_metadata(self, plugin_id: str) -> Optional[PluginMetadata]:
        """Get metadata for a plugin."""
        plugin = self._plugins.get(plugin_id)
        return plugin.metadata if plugin else None

    def get_all_metadata(self) -> Dict[str, PluginMetadata]:
        """Get metadata for all plugins."""
        return {pid: p.metadata for pid, p in self._plugins.items()}

    # =========================================================================
    # Plugin Discovery
    # =========================================================================

    def discover_plugins(self, include_entry_points: bool = True) -> int:
        """
        Discover and register all available plugins.

        Args:
            include_entry_points: Whether to load from entry points

        Returns:
            Number of plugins discovered
        """
        count = 0

        # Discover built-in plugins
        count += self._discover_builtin_plugins()

        # Discover entry point plugins
        if include_entry_points:
            count += self._discover_entry_point_plugins()

        logger.info(f"Discovered {count} plugins total")
        return count

    def _discover_builtin_plugins(self) -> int:
        """Discover built-in plugins from the sources directory."""
        count = 0

        # Import built-in sources
        builtin_sources = [
            ("mit_ocw", "..sources.mit_ocw", "MITOCWPlugin"),
            # Add more built-in sources here as they are created
            # ("stanford_see", "..sources.stanford_see", "StanfordSEEPlugin"),
            # ("ck12", "..sources.ck12", "CK12Plugin"),
            # ("fastai", "..sources.fastai", "FastAIPlugin"),
        ]

        for source_id, module_path, class_name in builtin_sources:
            try:
                # Skip if already registered
                if source_id in self._plugins:
                    continue

                # Dynamic import
                import importlib
                module = importlib.import_module(module_path, package=__name__)
                plugin_class = getattr(module, class_name, None)

                if plugin_class is None:
                    # Try legacy handler and wrap it
                    legacy_class_name = class_name.replace("Plugin", "Handler")
                    legacy_class = getattr(module, legacy_class_name, None)
                    if legacy_class:
                        logger.debug(
                            f"Found legacy handler {legacy_class_name}, "
                            f"wrapping as plugin"
                        )
                        # Will be handled by adapter in migration
                        continue
                    logger.debug(f"Plugin class {class_name} not found in {module_path}")
                    continue

                plugin = plugin_class()
                self.register(plugin)
                count += 1

            except ImportError as e:
                logger.debug(f"Could not import {module_path}: {e}")
            except Exception as e:
                logger.warning(f"Error loading built-in plugin {source_id}: {e}")

        return count

    def _discover_entry_point_plugins(self) -> int:
        """Discover plugins from setuptools entry points."""
        count = 0

        entry_point_groups = [
            (self.ENTRY_POINT_SOURCES, PluginType.SOURCE),
            (self.ENTRY_POINT_PARSERS, PluginType.PARSER),
            (self.ENTRY_POINT_ENRICHERS, PluginType.ENRICHER),
            (self.ENTRY_POINT_EXPORTERS, PluginType.EXPORTER),
            (self.ENTRY_POINT_VALIDATORS, PluginType.VALIDATOR),
        ]

        for group_name, plugin_type in entry_point_groups:
            try:
                # Python 3.10+ API
                eps = importlib.metadata.entry_points(group=group_name)
            except TypeError:
                # Python 3.9 fallback
                all_eps = importlib.metadata.entry_points()
                eps = all_eps.get(group_name, [])

            for ep in eps:
                try:
                    # Skip if already registered
                    if ep.name in self._plugins:
                        continue

                    # Load the plugin class
                    plugin_class = ep.load()
                    plugin = plugin_class()

                    # Verify it implements the protocol
                    if not isinstance(plugin, ImporterPlugin):
                        logger.warning(
                            f"Entry point {ep.name} does not implement ImporterPlugin"
                        )
                        continue

                    self.register(plugin)
                    count += 1
                    logger.info(f"Loaded entry point plugin: {ep.name} from {ep.value}")

                except Exception as e:
                    logger.error(f"Failed to load entry point {ep.name}: {e}")

        return count

    # =========================================================================
    # Configuration
    # =========================================================================

    def configure_plugin(self, plugin_id: str, config: PluginConfig) -> List[str]:
        """
        Configure a specific plugin.

        Args:
            plugin_id: Plugin to configure
            config: Configuration to apply

        Returns:
            List of validation errors (empty if valid)
        """
        plugin = self._plugins.get(plugin_id)
        if plugin is None:
            return [f"Plugin '{plugin_id}' not found"]

        # Validate configuration
        errors = self.hook.validate_config(config=config)
        # Flatten list of lists from multiple plugins
        all_errors = []
        for err_list in errors:
            if err_list:
                all_errors.extend(err_list)

        if all_errors:
            return all_errors

        # Apply configuration
        self._configs[plugin_id] = config
        self.hook.configure(config=config)

        return []

    def get_plugin_config(self, plugin_id: str) -> Optional[PluginConfig]:
        """Get configuration for a plugin."""
        return self._configs.get(plugin_id)

    # =========================================================================
    # Async Hook Helpers
    # =========================================================================

    async def call_async_hook(
        self,
        hook_name: str,
        **kwargs: Any,
    ) -> List[Any]:
        """
        Call an async hook and await all results.

        Args:
            hook_name: Name of the hook to call
            **kwargs: Hook arguments

        Returns:
            List of results from all implementations
        """
        hook = getattr(self.hook, hook_name)
        results = hook(**kwargs)

        # Gather async results
        async_results = []
        for result in results:
            if asyncio.iscoroutine(result):
                async_results.append(await result)
            else:
                async_results.append(result)

        return async_results

    async def call_async_hook_first(
        self,
        hook_name: str,
        **kwargs: Any,
    ) -> Any:
        """
        Call a firstresult async hook.

        Args:
            hook_name: Name of the hook to call
            **kwargs: Hook arguments

        Returns:
            First non-None result
        """
        hook = getattr(self.hook, hook_name)
        result = hook(**kwargs)

        if asyncio.iscoroutine(result):
            return await result
        return result


# Global plugin manager instance
_manager: Optional[PluginManager] = None


def get_plugin_manager() -> PluginManager:
    """
    Get the global plugin manager instance.

    Creates the manager on first call.

    Returns:
        The global PluginManager
    """
    global _manager
    if _manager is None:
        _manager = PluginManager()
    return _manager


def reset_plugin_manager() -> None:
    """Reset the global plugin manager. Mainly for testing."""
    global _manager
    _manager = None


class PluginRegistry:
    """
    Decorator-based plugin registration.

    Provides a convenient way to register plugins using decorators,
    similar to the legacy SourceRegistry pattern.

    Example:
        @PluginRegistry.register
        class MyPlugin(BaseImporterPlugin):
            ...
    """

    _pending: List[Type[BaseImporterPlugin]] = []

    @classmethod
    def register(cls, plugin_class: Type[BaseImporterPlugin]) -> Type[BaseImporterPlugin]:
        """
        Register a plugin class.

        The actual registration with PluginManager happens when
        discover_plugins() is called.

        Args:
            plugin_class: Plugin class to register

        Returns:
            The plugin class (for decorator use)
        """
        cls._pending.append(plugin_class)
        return plugin_class

    @classmethod
    def register_pending(cls, manager: PluginManager) -> int:
        """
        Register all pending plugin classes with a manager.

        Args:
            manager: PluginManager to register with

        Returns:
            Number of plugins registered
        """
        count = 0
        for plugin_class in cls._pending:
            try:
                plugin = plugin_class()
                manager.register(plugin)
                count += 1
            except Exception as e:
                logger.error(f"Failed to register {plugin_class.__name__}: {e}")

        cls._pending.clear()
        return count

    @classmethod
    def clear(cls) -> None:
        """Clear pending registrations. Mainly for testing."""
        cls._pending.clear()
