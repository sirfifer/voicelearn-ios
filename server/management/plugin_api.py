"""
API routes for plugin management.

These routes power the Plugin Manager in the management dashboard,
enabling users to:
- View all discovered plugins
- Enable/disable plugins
- Configure plugin settings
- Trigger first-run wizard
"""

import logging
from pathlib import Path
from typing import Optional

from aiohttp import web

# Import the importer package
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from importers.core.discovery import get_plugin_discovery, PluginDiscovery
from importers.core.registry import SourceRegistry

logger = logging.getLogger(__name__)

# Global discovery instance
_discovery: Optional[PluginDiscovery] = None


def get_discovery() -> PluginDiscovery:
    """Get the plugin discovery instance."""
    global _discovery
    if _discovery is None:
        _discovery = get_plugin_discovery()
        _discovery.discover_all()
        _discovery.load_state()
    return _discovery


def init_plugin_system():
    """Initialize the plugin system (call on server startup)."""
    logger.info("Initializing plugin system...")
    discovery = get_discovery()
    discovered = len(discovery._discovered)
    enabled = len(discovery.get_enabled_plugins())
    logger.info(f"Plugin system initialized: {discovered} discovered, {enabled} enabled")

    # Check if first-run wizard is needed
    if not discovery.has_state_file():
        logger.info("No plugin state file found - first-run wizard will be triggered")


# =============================================================================
# Plugin Routes
# =============================================================================

async def handle_get_plugins(request: web.Request) -> web.Response:
    """
    GET /api/plugins

    Get list of all discovered plugins with their enabled state.
    """
    try:
        discovery = get_discovery()

        plugins = []
        for plugin in discovery._discovered.values():
            state = discovery._states.get(plugin.plugin_id)
            plugins.append({
                **plugin.to_dict(),
                "enabled": state.enabled if state else False,
                "priority": state.priority if state else 100,
                "settings": state.settings if state else {},
            })

        return web.json_response({
            "success": True,
            "plugins": plugins,
            "first_run": not discovery.has_state_file(),
        })
    except Exception as e:
        logger.exception("Error getting plugins")
        return web.json_response({
            "success": False,
            "error": str(e),
        }, status=500)


async def handle_get_plugin(request: web.Request) -> web.Response:
    """
    GET /api/plugins/{plugin_id}

    Get details for a specific plugin.
    """
    plugin_id = request.match_info["plugin_id"]

    try:
        discovery = get_discovery()

        plugin = discovery._discovered.get(plugin_id)
        if not plugin:
            return web.json_response({
                "success": False,
                "error": f"Plugin not found: {plugin_id}",
            }, status=404)

        state = discovery._states.get(plugin_id)
        return web.json_response({
            "success": True,
            "plugin": {
                **plugin.to_dict(),
                "enabled": state.enabled if state else False,
                "priority": state.priority if state else 100,
                "settings": state.settings if state else {},
            },
        })
    except Exception as e:
        logger.exception(f"Error getting plugin {plugin_id}")
        return web.json_response({
            "success": False,
            "error": str(e),
        }, status=500)


async def handle_enable_plugin(request: web.Request) -> web.Response:
    """
    POST /api/plugins/{plugin_id}/enable

    Enable a plugin.
    """
    plugin_id = request.match_info["plugin_id"]

    try:
        discovery = get_discovery()

        if plugin_id not in discovery._discovered:
            return web.json_response({
                "success": False,
                "error": f"Plugin not found: {plugin_id}",
            }, status=404)

        success = discovery.enable_plugin(plugin_id)

        # Refresh the SourceRegistry to pick up the newly enabled plugin
        if success:
            SourceRegistry.refresh()

        return web.json_response({
            "success": success,
            "message": f"Plugin {plugin_id} enabled" if success else f"Failed to enable {plugin_id}",
        })
    except Exception as e:
        logger.exception(f"Error enabling plugin {plugin_id}")
        return web.json_response({
            "success": False,
            "error": str(e),
        }, status=500)


async def handle_disable_plugin(request: web.Request) -> web.Response:
    """
    POST /api/plugins/{plugin_id}/disable

    Disable a plugin.
    """
    plugin_id = request.match_info["plugin_id"]

    try:
        discovery = get_discovery()

        success = discovery.disable_plugin(plugin_id)

        # Refresh the SourceRegistry to remove the disabled plugin
        if success:
            SourceRegistry.refresh()

        return web.json_response({
            "success": success,
            "message": f"Plugin {plugin_id} disabled" if success else f"Failed to disable {plugin_id}",
        })
    except Exception as e:
        logger.exception(f"Error disabling plugin {plugin_id}")
        return web.json_response({
            "success": False,
            "error": str(e),
        }, status=500)


async def handle_configure_plugin(request: web.Request) -> web.Response:
    """
    POST /api/plugins/{plugin_id}/configure

    Update plugin settings.

    Body: { "settings": { ... } }
    """
    plugin_id = request.match_info["plugin_id"]

    try:
        discovery = get_discovery()

        if plugin_id not in discovery._discovered:
            return web.json_response({
                "success": False,
                "error": f"Plugin not found: {plugin_id}",
            }, status=404)

        body = await request.json()
        settings = body.get("settings", {})

        # Update settings
        if plugin_id not in discovery._states:
            from importers.core.discovery import PluginState
            discovery._states[plugin_id] = PluginState()

        discovery._states[plugin_id].settings = settings
        discovery.save_state()

        return web.json_response({
            "success": True,
            "message": f"Plugin {plugin_id} configured",
        })
    except Exception as e:
        logger.exception(f"Error configuring plugin {plugin_id}")
        return web.json_response({
            "success": False,
            "error": str(e),
        }, status=500)


async def handle_initialize_plugins(request: web.Request) -> web.Response:
    """
    POST /api/plugins/initialize

    Initialize plugin state with specified plugins enabled.
    Used by the first-run wizard.

    Body: { "enabled_plugins": ["mit_ocw", "ck12_flexbook"] }
    """
    try:
        discovery = get_discovery()

        body = await request.json()
        enabled_plugins = body.get("enabled_plugins", [])

        success = discovery.initialize_state(enabled_plugins)

        # Refresh the SourceRegistry
        if success:
            SourceRegistry.refresh()

        return web.json_response({
            "success": success,
            "message": f"Initialized {len(enabled_plugins)} plugins" if success else "Failed to initialize",
            "enabled": enabled_plugins,
        })
    except Exception as e:
        logger.exception("Error initializing plugins")
        return web.json_response({
            "success": False,
            "error": str(e),
        }, status=500)


async def handle_get_first_run_status(request: web.Request) -> web.Response:
    """
    GET /api/plugins/first-run

    Check if first-run wizard is needed.
    """
    try:
        discovery = get_discovery()

        return web.json_response({
            "success": True,
            "first_run_needed": not discovery.has_state_file(),
            "discovered_count": len(discovery._discovered),
        })
    except Exception as e:
        logger.exception("Error checking first-run status")
        return web.json_response({
            "success": False,
            "error": str(e),
        }, status=500)


# =============================================================================
# Route Registration
# =============================================================================

def register_plugin_routes(app: web.Application):
    """Register all plugin-related routes on the application."""

    # Initialize plugin system
    init_plugin_system()

    # Plugin listing
    app.router.add_get("/api/plugins", handle_get_plugins)
    app.router.add_get("/api/plugins/first-run", handle_get_first_run_status)
    app.router.add_post("/api/plugins/initialize", handle_initialize_plugins)

    # Individual plugin operations
    app.router.add_get("/api/plugins/{plugin_id}", handle_get_plugin)
    app.router.add_post("/api/plugins/{plugin_id}/enable", handle_enable_plugin)
    app.router.add_post("/api/plugins/{plugin_id}/disable", handle_disable_plugin)
    app.router.add_post("/api/plugins/{plugin_id}/configure", handle_configure_plugin)

    logger.info("Plugin API routes registered")
