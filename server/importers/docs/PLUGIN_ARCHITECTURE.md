# UnaMentis Importer Plugin Architecture

This document describes the plugin architecture for the UnaMentis curriculum importer framework.

## Overview

The plugin architecture provides:

- **Filesystem-Based Discovery**: Plugins are auto-discovered from the `plugins/` folder
- **Explicit Enable/Disable**: Plugins must be enabled via the Plugin Manager UI
- **Persistent State**: Plugin state (enabled/disabled) persists across restarts
- **First-Run Wizard**: New installations prompt users to select which plugins to enable
- **Standardized Interface**: All plugins extend `CurriculumSourceHandler`

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Management Console                           │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Plugin Manager Tab                        │ │
│  │  - View discovered plugins                                   │ │
│  │  - Enable/disable plugins with toggle                        │ │
│  │  - First-run wizard for new installations                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Plugin Discovery                             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    PluginDiscovery                           │ │
│  │  - Scans plugins/sources/, plugins/parsers/, etc.           │ │
│  │  - Extracts metadata from each plugin                        │ │
│  │  - Tracks enabled/disabled state in plugins.json             │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Source Registry                              │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    SourceRegistry                            │ │
│  │  - Returns only ENABLED plugins                              │ │
│  │  - Used by Source Browser and Import Orchestrator            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│  ┌───────────┬───────────────┼───────────────┬───────────────┐  │
│  │           │               │               │               │  │
│  ▼           ▼               ▼               ▼               ▼  │
│ ┌─────┐   ┌─────┐       ┌─────────┐    ┌─────────┐    ┌─────┐ │
│ │MIT  │   │CK-12│       │Future   │    │Future   │    │...  │ │
│ │OCW  │   │     │       │Source   │    │Source   │    │     │ │
│ └─────┘   └─────┘       └─────────┘    └─────────┘    └─────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Using the Plugin System

```python
from importers.core import init_plugin_system
from importers.core.registry import SourceRegistry

# Initialize and discover all plugins
discovery = init_plugin_system()

# List enabled plugins
for plugin in discovery.get_enabled_plugins():
    print(f"Plugin: {plugin.plugin_id}")
    print(f"  Name: {plugin.name}")
    print(f"  Type: {plugin.plugin_type}")

# Get a handler for an enabled source
handler = SourceRegistry.get_handler("mit_ocw")
if handler:
    source_info = handler.source_info
    print(f"Source: {source_info.name}")

# Browse the catalog
import asyncio

async def browse_catalog():
    handler = SourceRegistry.get_handler("mit_ocw")
    if handler:
        courses, total, filters = await handler.get_course_catalog(
            page=1,
            page_size=20,
            filters=None,
            search="machine learning",
        )
        print(f"Found {total} courses")
        for course in courses:
            print(f"  - {course.title}")

asyncio.run(browse_catalog())
```

### Creating a New Plugin

Create a new file in `plugins/sources/`:

```python
# plugins/sources/my_source.py
"""
My Custom Curriculum Source

This plugin imports curriculum from My Source.
"""

from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple

from ...core.base import (
    CurriculumSourceHandler,
    LicenseValidationResult,
)
from ...core.models import (
    CourseCatalogEntry,
    CourseDetail,
    CurriculumSource,
    LicenseInfo,
)
from ...core.registry import SourceRegistry


@SourceRegistry.register
class MySourceHandler(CurriculumSourceHandler):
    """Handler for My Custom Source."""

    @property
    def source_id(self) -> str:
        return "my_source"

    @property
    def source_info(self) -> CurriculumSource:
        return CurriculumSource(
            id=self.source_id,
            name="My Source",
            description="Description of my curriculum source",
            logo_url="https://example.com/logo.png",
            license=self.default_license,
            course_count="100+",
            features=["video", "transcript", "assignments"],
            status="active",
            base_url="https://example.com",
        )

    @property
    def default_license(self) -> LicenseInfo:
        return LicenseInfo(
            type="CC-BY-4.0",
            name="Creative Commons Attribution 4.0",
            url="https://creativecommons.org/licenses/by/4.0/",
            permissions=["share", "adapt", "commercial"],
            conditions=["attribution"],
            attribution_required=True,
            attribution_format="Content from My Source",
            holder_name="My Source",
            holder_url="https://example.com",
            restrictions=[],
        )

    async def get_course_catalog(
        self,
        page: int = 1,
        page_size: int = 20,
        filters: Optional[Dict[str, Any]] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[CourseCatalogEntry], int, Dict[str, List[str]]]:
        """Get paginated course catalog."""
        # Implement catalog retrieval
        courses = []
        total = 0
        filter_options = {"subject": [], "level": []}
        return courses, total, filter_options

    async def get_course_detail(self, course_id: str) -> Optional[CourseDetail]:
        """Get detailed course information."""
        # Implement course detail retrieval
        return None

    def validate_license(self, course_id: str) -> LicenseValidationResult:
        """Validate license for a course."""
        return LicenseValidationResult(
            can_import=True,
            license=self.default_license,
            warnings=[],
            attribution_text=f"Content from My Source",
        )

    async def download_course(
        self,
        course_id: str,
        output_dir: Path,
        progress_callback: Optional[Callable[[int, str], None]] = None,
        selected_lectures: Optional[List[str]] = None,
    ) -> Path:
        """Download course content."""
        # Implement download logic
        course_dir = output_dir / course_id
        course_dir.mkdir(parents=True, exist_ok=True)
        return course_dir
```

After creating the plugin:

1. Restart the management server
2. Go to the Plugin Manager tab
3. Enable your new plugin with the toggle switch
4. It will now appear in the Source Browser

## Plugin Discovery

### How Discovery Works

The `PluginDiscovery` class in `core/discovery.py` handles plugin discovery:

1. **Startup**: Server calls `discover_all()` to scan plugin folders
2. **Scanning**: Looks in `plugins/sources/`, `plugins/parsers/`, `plugins/enrichers/`
3. **Loading**: For each `.py` file (excluding `__init__.py` and `_*.py`):
   - Loads the module
   - Finds classes ending in `Handler` or `Plugin`
   - Extracts metadata from the class instance
4. **State**: Loads enabled/disabled state from `plugins.json`

### Plugin State File

Plugin state is stored in `management/data/plugins.json`:

```json
{
  "mit_ocw": {
    "enabled": true,
    "priority": 100,
    "settings": {}
  },
  "ck12_flexbook": {
    "enabled": true,
    "priority": 100,
    "settings": {}
  }
}
```

## Plugin API

The management server exposes these endpoints for plugin management:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/plugins` | GET | List all discovered plugins with state |
| `/api/plugins/{id}` | GET | Get plugin details |
| `/api/plugins/{id}/enable` | POST | Enable a plugin |
| `/api/plugins/{id}/disable` | POST | Disable a plugin |
| `/api/plugins/{id}/configure` | POST | Update plugin settings |
| `/api/plugins/initialize` | POST | Initialize plugins (first-run) |
| `/api/plugins/first-run` | GET | Check if first-run wizard needed |

### Example API Usage

```bash
# List all plugins
curl http://localhost:8766/api/plugins

# Enable a plugin
curl -X POST http://localhost:8766/api/plugins/mit_ocw/enable

# Disable a plugin
curl -X POST http://localhost:8766/api/plugins/ck12_flexbook/disable

# Initialize with specific plugins enabled
curl -X POST http://localhost:8766/api/plugins/initialize \
  -H "Content-Type: application/json" \
  -d '{"enabled_plugins": ["mit_ocw"]}'
```

## Source Registry

The `SourceRegistry` class provides access to enabled plugins only:

```python
from importers.core.registry import SourceRegistry

# Get a specific handler (returns None if not enabled)
handler = SourceRegistry.get_handler("mit_ocw")

# Get all enabled handlers
handlers = SourceRegistry.get_all_handlers()

# Get source info for all enabled handlers
sources = SourceRegistry.get_all_sources()

# List enabled source IDs
source_ids = SourceRegistry.list_source_ids()

# Check if a source is enabled
is_enabled = SourceRegistry.is_registered("mit_ocw")

# Refresh after enabling/disabling plugins
SourceRegistry.refresh()
```

## First-Run Wizard

When the management console is opened for the first time (no `plugins.json` exists):

1. The Plugin Manager tab shows a banner indicating first-run
2. Users can click "Open Setup Wizard" to configure initial plugins
3. The wizard allows selecting which plugins to enable
4. Selections are saved to `plugins.json`
5. The banner is hidden after initialization

## Plugin Types

| Type | Location | Description |
|------|----------|-------------|
| Sources | `plugins/sources/` | Import curriculum from external sources |
| Parsers | `plugins/parsers/` | Parse specific content formats (future) |
| Enrichers | `plugins/enrichers/` | AI-powered content enrichment (future) |

## File Structure

```
server/importers/
├── plugins/                    # All plugins live here
│   ├── __init__.py
│   ├── sources/               # Source importer plugins
│   │   ├── __init__.py
│   │   ├── mit_ocw.py         # MIT OpenCourseWare
│   │   └── ck12_flexbook.py   # CK-12 FlexBooks
│   ├── parsers/               # Parser plugins (future)
│   │   └── __init__.py
│   └── enrichers/             # Enricher plugins (future)
│       └── __init__.py
├── core/
│   ├── __init__.py            # Public exports
│   ├── base.py                # CurriculumSourceHandler base class
│   ├── discovery.py           # Plugin discovery system
│   ├── registry.py            # SourceRegistry (enabled plugins only)
│   ├── plugin.py              # PluginManager and types
│   ├── models.py              # Data models
│   └── orchestrator.py        # Import orchestration
├── data/                      # Catalog data files
│   ├── mit_ocw_catalog.json
│   └── ck12_catalog.json
└── tests/                     # Test suite
    ├── test_plugin_architecture.py
    ├── test_ck12_flexbook.py
    └── test_orchestrator.py

server/management/
├── data/
│   └── plugins.json           # Persistent plugin state
├── plugin_api.py              # Plugin management API
├── server.py                  # Main server (registers plugin routes)
└── static/
    ├── index.html             # UI with Plugin Manager tab
    └── app.js                 # JavaScript including plugin functions
```

## Testing

```bash
cd server/importers

# Run all tests
python -m pytest tests/ -v

# Run plugin architecture tests
python -m pytest tests/test_plugin_architecture.py -v

# Run with coverage
python -m pytest tests/ --cov=core --cov-report=html
```

## Adding a New Plugin

1. Create a new `.py` file in the appropriate `plugins/` subdirectory
2. Implement the required interface (e.g., `CurriculumSourceHandler` for sources)
3. Decorate the class with `@SourceRegistry.register`
4. Restart the server to discover the new plugin
5. Enable it in the Plugin Manager tab

The plugin will automatically be discovered and available for enabling in the UI.
