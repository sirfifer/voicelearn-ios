"""
Source registry for curriculum source handlers.

This module provides access to enabled curriculum source plugins.
Plugins are discovered from the plugins/ folder but only enabled
plugins are accessible through this registry.

Use the Plugin Manager in the Management Console to enable/disable plugins.
"""

import logging
from typing import Dict, List, Optional, Type

from .base import CurriculumSourceHandler
from .models import CurriculumSource

logger = logging.getLogger(__name__)


class SourceRegistry:
    """
    Registry for enabled curriculum source handlers.

    This class provides access to ENABLED plugins only. Plugins must be
    enabled through the Plugin Manager before they appear here.

    The registry uses the discovery system to find plugins and checks
    the enabled state before returning them.
    """

    _instances: Dict[str, CurriculumSourceHandler] = {}
    _discovery_initialized: bool = False

    @classmethod
    def _ensure_initialized(cls) -> None:
        """Ensure the discovery system is initialized."""
        if cls._discovery_initialized:
            return

        from .discovery import get_plugin_discovery

        discovery = get_plugin_discovery()
        discovery.discover_all()
        discovery.load_state()
        cls._discovery_initialized = True

    @classmethod
    def _load_enabled_handlers(cls) -> None:
        """Load handler instances for all enabled plugins."""
        from .discovery import get_plugin_discovery

        cls._ensure_initialized()
        discovery = get_plugin_discovery()

        # Clear existing instances
        cls._instances.clear()

        # Load enabled plugins
        for plugin in discovery.get_enabled_plugins():
            try:
                handler_class = discovery.get_plugin_class(plugin.plugin_id)
                if handler_class:
                    instance = handler_class()
                    cls._instances[plugin.plugin_id] = instance
                    logger.debug(f"Loaded enabled handler: {plugin.plugin_id}")
            except Exception as e:
                logger.error(f"Failed to load handler {plugin.plugin_id}: {e}")

    @classmethod
    def register(cls, handler_class: Type[CurriculumSourceHandler]) -> Type[CurriculumSourceHandler]:
        """
        Register a source handler class.

        This decorator is kept for backwards compatibility but handlers
        are now discovered from the plugins/ folder automatically.

        Args:
            handler_class: Handler class to register

        Returns:
            The handler class (for decorator use)
        """
        # Just return the class - discovery happens via filesystem scan
        # This decorator is maintained for backwards compatibility
        return handler_class

    @classmethod
    def get_handler(cls, source_id: str) -> Optional[CurriculumSourceHandler]:
        """
        Get a handler instance by source ID.

        Only returns handlers for ENABLED plugins.

        Args:
            source_id: Source identifier (e.g., "mit_ocw")

        Returns:
            Handler instance or None if not found or not enabled
        """
        from .discovery import get_plugin_discovery

        cls._ensure_initialized()
        discovery = get_plugin_discovery()

        # Check if plugin is enabled
        if not discovery.is_enabled(source_id):
            logger.debug(f"Handler {source_id} not enabled")
            return None

        # Check if already loaded
        if source_id in cls._instances:
            return cls._instances[source_id]

        # Try to load it
        handler_class = discovery.get_plugin_class(source_id)
        if handler_class:
            try:
                instance = handler_class()
                cls._instances[source_id] = instance
                return instance
            except Exception as e:
                logger.error(f"Failed to instantiate handler {source_id}: {e}")

        return None

    @classmethod
    def get_all_handlers(cls) -> List[CurriculumSourceHandler]:
        """
        Get all enabled handlers.

        Returns:
            List of handler instances for ENABLED plugins only
        """
        from .discovery import get_plugin_discovery

        cls._ensure_initialized()
        discovery = get_plugin_discovery()

        handlers = []
        for plugin in discovery.get_enabled_plugins():
            handler = cls.get_handler(plugin.plugin_id)
            if handler:
                handlers.append(handler)

        return handlers

    @classmethod
    def get_all_sources(cls) -> List[CurriculumSource]:
        """
        Get source information for all enabled handlers.

        Returns:
            List of CurriculumSource objects for ENABLED plugins only
        """
        return [handler.source_info for handler in cls.get_all_handlers()]

    @classmethod
    def list_source_ids(cls) -> List[str]:
        """
        List all enabled source IDs.

        Returns:
            List of source IDs for ENABLED plugins only
        """
        from .discovery import get_plugin_discovery

        cls._ensure_initialized()
        discovery = get_plugin_discovery()

        return [plugin.plugin_id for plugin in discovery.get_enabled_plugins()]

    @classmethod
    def is_registered(cls, source_id: str) -> bool:
        """
        Check if a source is registered AND enabled.

        Args:
            source_id: Source identifier

        Returns:
            True if registered and enabled
        """
        from .discovery import get_plugin_discovery

        cls._ensure_initialized()
        discovery = get_plugin_discovery()

        return discovery.is_enabled(source_id)

    @classmethod
    def clear(cls) -> None:
        """Clear all loaded handlers. Mainly for testing."""
        cls._instances.clear()
        cls._discovery_initialized = False

    @classmethod
    def refresh(cls) -> None:
        """Refresh the registry from discovery. Call after enabling/disabling plugins."""
        cls._instances.clear()
        cls._discovery_initialized = False
        cls._ensure_initialized()


def discover_handlers() -> None:
    """
    Discover all available source handlers.

    This function triggers plugin discovery from the plugins/ folder.
    Discovered plugins are NOT automatically enabled.

    Call this at application startup.
    """
    from .discovery import get_plugin_discovery

    discovery = get_plugin_discovery()
    plugins = discovery.discover_all()
    discovery.load_state()

    enabled_count = len(discovery.get_enabled_plugins())
    logger.info(f"Plugin discovery complete: {len(plugins)} discovered, {enabled_count} enabled")


def init_plugin_system() -> "PluginDiscovery":  # type: ignore[name-defined]
    """
    Initialize the plugin system.

    This is the recommended way to set up the importer framework.
    It discovers all plugins and loads their enabled state.

    Returns:
        The PluginDiscovery instance

    Example:
        from importers.core.registry import init_plugin_system

        discovery = init_plugin_system()
        enabled = discovery.get_enabled_plugins()
    """
    from .discovery import get_plugin_discovery

    discover_handlers()
    return get_plugin_discovery()
