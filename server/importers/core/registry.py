"""
Source registry for discovering and accessing curriculum source handlers.

This module provides backwards compatibility with the legacy registry pattern
while integrating with the new plugin architecture.

The legacy SourceRegistry is maintained for compatibility but delegates to
the new PluginManager for plugin discovery and management.
"""

import logging
from typing import Dict, List, Optional, Type

from .base import CurriculumSourceHandler
from .models import CurriculumSource

logger = logging.getLogger(__name__)


class SourceRegistry:
    """
    Registry for curriculum source handlers.

    LEGACY: This class is maintained for backwards compatibility.
    New code should use PluginManager directly.

    Provides:
    - Source registration
    - Source discovery
    - Handler instantiation

    The registry now integrates with the new plugin architecture:
    - Registered handlers are automatically wrapped and added to PluginManager
    - get_handler() checks both legacy registry and PluginManager
    """

    _handlers: Dict[str, Type[CurriculumSourceHandler]] = {}
    _instances: Dict[str, CurriculumSourceHandler] = {}
    _use_plugin_manager: bool = True

    @classmethod
    def register(cls, handler_class: Type[CurriculumSourceHandler]) -> Type[CurriculumSourceHandler]:
        """
        Register a source handler class.

        Can be used as a decorator:
            @SourceRegistry.register
            class MITOCWHandler(CurriculumSourceHandler):
                ...

        Args:
            handler_class: Handler class to register

        Returns:
            The handler class (for decorator use)
        """
        # Instantiate to get source_id
        instance = handler_class()
        cls._handlers[instance.source_id] = handler_class
        cls._instances[instance.source_id] = instance

        # Also register with new plugin system if available
        if cls._use_plugin_manager:
            try:
                from .adapter import LegacySourceAdapter
                from .plugin import get_plugin_manager

                manager = get_plugin_manager()
                adapter = LegacySourceAdapter(instance)
                manager.register(adapter)
                logger.debug(f"Registered {instance.source_id} with PluginManager")
            except ImportError:
                pass  # Plugin system not available
            except Exception as e:
                logger.warning(f"Failed to register with PluginManager: {e}")

        return handler_class

    @classmethod
    def get_handler(cls, source_id: str) -> Optional[CurriculumSourceHandler]:
        """
        Get a handler instance by source ID.

        Checks both the legacy registry and the new PluginManager.

        Args:
            source_id: Source identifier (e.g., "mit_ocw")

        Returns:
            Handler instance or None if not found
        """
        # Check legacy registry first
        handler = cls._instances.get(source_id)
        if handler:
            return handler

        # Check plugin manager for wrapped handlers
        if cls._use_plugin_manager:
            try:
                from .adapter import LegacySourceAdapter
                from .plugin import get_plugin_manager

                manager = get_plugin_manager()
                plugin = manager.get_source(source_id)
                if plugin and isinstance(plugin, LegacySourceAdapter):
                    return plugin.handler
            except ImportError:
                pass

        return None

    @classmethod
    def get_all_handlers(cls) -> List[CurriculumSourceHandler]:
        """
        Get all registered handlers.

        Returns:
            List of handler instances
        """
        handlers = list(cls._instances.values())

        # Also include handlers from plugin manager
        if cls._use_plugin_manager:
            try:
                from .adapter import LegacySourceAdapter
                from .plugin import get_plugin_manager

                manager = get_plugin_manager()
                for plugin in manager.list_sources():
                    if isinstance(plugin, LegacySourceAdapter):
                        if plugin.handler not in handlers:
                            handlers.append(plugin.handler)
            except ImportError:
                pass

        return handlers

    @classmethod
    def get_all_sources(cls) -> List[CurriculumSource]:
        """
        Get source information for all registered handlers.

        Returns:
            List of CurriculumSource objects
        """
        return [handler.source_info for handler in cls.get_all_handlers()]

    @classmethod
    def list_source_ids(cls) -> List[str]:
        """
        List all registered source IDs.

        Returns:
            List of source IDs
        """
        source_ids = set(cls._handlers.keys())

        # Include plugin manager sources
        if cls._use_plugin_manager:
            try:
                from .plugin import get_plugin_manager

                manager = get_plugin_manager()
                for plugin in manager.list_sources():
                    source_ids.add(plugin.plugin_id)
            except ImportError:
                pass

        return list(source_ids)

    @classmethod
    def is_registered(cls, source_id: str) -> bool:
        """
        Check if a source is registered.

        Args:
            source_id: Source identifier

        Returns:
            True if registered
        """
        if source_id in cls._handlers:
            return True

        if cls._use_plugin_manager:
            try:
                from .plugin import get_plugin_manager

                manager = get_plugin_manager()
                return manager.get_source(source_id) is not None
            except ImportError:
                pass

        return False

    @classmethod
    def clear(cls):
        """Clear all registered handlers. Mainly for testing."""
        cls._handlers.clear()
        cls._instances.clear()

    @classmethod
    def disable_plugin_manager(cls):
        """Disable plugin manager integration. Mainly for testing."""
        cls._use_plugin_manager = False

    @classmethod
    def enable_plugin_manager(cls):
        """Enable plugin manager integration."""
        cls._use_plugin_manager = True


def discover_handlers():
    """
    Discover and register all available source handlers.

    This function imports handler modules to trigger registration.
    Call this at application startup.

    For the new plugin architecture, also initializes the PluginManager.
    """
    # Initialize plugin manager and discover plugins
    try:
        from .adapter import discover_and_wrap_legacy_handlers
        from .plugin import PluginRegistry, get_plugin_manager

        manager = get_plugin_manager()

        # Register any pending plugin classes
        PluginRegistry.register_pending(manager)

        # Discover and wrap legacy handlers
        adapters = discover_and_wrap_legacy_handlers()
        for adapter in adapters:
            if not manager.get_plugin(adapter.plugin_id):
                manager.register(adapter)

        # Discover entry point plugins
        manager.discover_plugins(include_entry_points=True)

        logger.info(f"Plugin discovery complete: {len(manager.list_sources())} sources")

    except ImportError as e:
        logger.debug(f"Plugin system not available: {e}")
        # Fall back to legacy discovery

    # Import handler modules to trigger @SourceRegistry.register decorators
    try:
        from ..sources import mit_ocw  # noqa: F401
    except ImportError:
        pass

    try:
        from ..sources import stanford_see  # noqa: F401
    except ImportError:
        pass

    try:
        from ..sources import ck12  # noqa: F401
    except ImportError:
        pass

    try:
        from ..sources import fastai  # noqa: F401
    except ImportError:
        pass


def init_plugin_system() -> "PluginManager":  # type: ignore[name-defined]
    """
    Initialize the plugin system.

    This is the recommended way to set up the importer framework.
    It initializes the PluginManager and discovers all plugins.

    Returns:
        The initialized PluginManager

    Example:
        from importers.core.registry import init_plugin_system

        manager = init_plugin_system()
        sources = manager.list_sources()
    """
    from .plugin import get_plugin_manager

    discover_handlers()
    return get_plugin_manager()
