# Curriculum Importer Framework

Python framework for importing external curriculum sources into UMLCF format.

## Purpose

Ingest curriculum from external sources (MIT OCW, Stanford SEE, Fast.ai, CK-12) and convert to the UnaMentis Curriculum Format (UMLCF).

## Plugin Architecture

The framework uses an **industry-standard plugin architecture** based on [Pluggy](https://pluggy.readthedocs.io/) (the same system used by pytest). This enables:

- **External Plugins**: Third-party sources via setuptools entry points
- **Standardized Contracts**: Hook specifications define clear interfaces
- **Legacy Compatibility**: Existing handlers work via adapters
- **Configuration Management**: Per-plugin configuration with validation

See `docs/PLUGIN_ARCHITECTURE.md` for complete documentation.

### Quick Start

```python
from importers.core import init_plugin_system

# Initialize and discover all plugins
manager = init_plugin_system()

# List available sources
for source in manager.list_sources():
    print(f"Source: {source.plugin_id} (v{source.metadata.version})")

# Use a source plugin
mit = manager.get_source("mit_ocw")
```

### Creating a New Plugin

```python
from importers.core import BaseImporterPlugin, PluginRegistry, hookimpl

@PluginRegistry.register
class MySourcePlugin(BaseImporterPlugin):
    plugin_id = "my_source"
    plugin_type = PluginType.SOURCE

    @hookimpl
    def get_source_info(self) -> CurriculumSource:
        return CurriculumSource(...)

    @hookimpl
    async def get_course_catalog(self, page, page_size, filters, search):
        return courses, total, filter_options
```

## Architecture

```
importers/
├── core/              # Framework core
│   ├── base.py        # Legacy base class (CurriculumSourceHandler)
│   ├── plugin.py      # Plugin architecture (Pluggy-based)
│   ├── adapter.py     # Legacy handler adapter
│   ├── models.py      # Data models
│   ├── registry.py    # Plugin discovery & registration
│   └── orchestrator.py # Import orchestration engine
├── sources/           # Source-specific plugins
│   └── mit_ocw.py     # MIT OpenCourseWare (legacy handler)
├── parsers/           # Content parsers (Phase 2)
├── enrichment/        # AI enrichment pipeline (Phase 3)
├── tests/             # Plugin & integration tests
├── docs/              # Documentation
│   └── PLUGIN_ARCHITECTURE.md  # Full plugin docs
├── data/              # Runtime data
└── output/            # Import output
```

## Plugin Types

| Type | Description | Key Hooks |
|------|-------------|-----------|
| `SOURCE` | Curriculum sources | `get_course_catalog`, `download_course` |
| `PARSER` | Content parsers | `parse_content`, `get_supported_formats` |
| `ENRICHER` | AI enrichment | `enrich_content`, `get_enrichment_stages` |
| `EXPORTER` | Output exporters | `export_content`, `get_export_formats` |
| `VALIDATOR` | Content validators | `validate_content` |

## Key Patterns

### New Plugin Pattern (Recommended)

Use `BaseImporterPlugin` and `@hookimpl` decorators:

```python
@PluginRegistry.register
class MyPlugin(BaseImporterPlugin):
    @hookimpl
    def get_source_info(self) -> CurriculumSource:
        ...
```

### Legacy Handler Pattern

Legacy handlers still work via `@SourceRegistry.register`:

```python
@SourceRegistry.register
class MITOCWHandler(CurriculumSourceHandler):
    ...
```

They are automatically wrapped and registered with the plugin manager.

## Entry Points

External plugins register via `pyproject.toml`:

```toml
[project.entry-points."unamentis.importers.sources"]
my_source = "my_package:MySourcePlugin"
```

## Testing

```bash
cd server/importers
pip install -e ".[dev]"  # Install with dev dependencies
pytest tests/            # Run all tests
pytest tests/test_plugin_architecture.py  # Plugin tests only
```

## Dependencies

- `pluggy>=1.3.0` - Plugin framework
- `aiohttp>=3.8.0` - Async HTTP
- `beautifulsoup4>=4.12.0` - HTML parsing

Install via:
```bash
pip install -e .
```

## Importer Specifications

Detailed specs for each source are in `curriculum/importers/`:
- `MIT_OCW_IMPORTER_SPEC.md`
- `STANFORD_SEE_IMPORTER_SPEC.md`
- `FASTAI_IMPORTER_SPEC.md`
- `CK12_IMPORTER_SPEC.md`

## Output Format

All importers produce UMLCF-compliant JSON. See `curriculum/spec/` for the full specification.
