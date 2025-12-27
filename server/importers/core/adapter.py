"""
Legacy Adapter for migrating existing handlers to the plugin architecture.

This module provides adapters that wrap legacy CurriculumSourceHandler
implementations to work with the new plugin system.

This allows a gradual migration path:
1. Existing handlers continue to work unchanged
2. New plugins use the plugin architecture directly
3. Legacy handlers can be wrapped and registered as plugins
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple, Type

from .base import CurriculumSourceHandler, LicenseValidationResult, ValidationResult
from .models import CourseCatalogEntry, CourseDetail, CurriculumSource, LicenseInfo
from .plugin import (
    BaseImporterPlugin,
    PluginConfig,
    PluginMetadata,
    PluginType,
    hookimpl,
)

logger = logging.getLogger(__name__)


class LegacySourceAdapter(BaseImporterPlugin):
    """
    Adapter that wraps a legacy CurriculumSourceHandler as a plugin.

    This allows existing handlers to be used with the new plugin architecture
    without modification.

    Example:
        handler = MITOCWHandler()
        plugin = LegacySourceAdapter(handler)
        manager.register(plugin)

    Or use the factory:
        plugin = LegacySourceAdapter.from_handler_class(MITOCWHandler)
        manager.register(plugin)
    """

    def __init__(self, handler: CurriculumSourceHandler) -> None:
        """
        Create an adapter for a legacy handler.

        Args:
            handler: The legacy handler instance to wrap
        """
        self._handler = handler
        self._id = handler.source_id

        # Create metadata from handler info
        source_info = handler.source_info
        self._metadata = PluginMetadata(
            name=source_info.name,
            version="1.0.0",  # Legacy handlers don't have versions
            description=source_info.description,
            plugin_type=PluginType.SOURCE,
            author=None,
            url=source_info.base_url,
            requires=[],
            provides=[f"source:{self._id}"],
        )

    @classmethod
    def from_handler_class(
        cls,
        handler_class: Type[CurriculumSourceHandler],
    ) -> "LegacySourceAdapter":
        """
        Create an adapter from a handler class.

        Args:
            handler_class: The handler class to instantiate and wrap

        Returns:
            Adapter wrapping the handler
        """
        handler = handler_class()
        return cls(handler)

    @property
    def plugin_id(self) -> str:
        """Get plugin ID (same as source_id)."""
        return self._id

    @property
    def plugin_type(self) -> PluginType:
        """This is a source plugin."""
        return PluginType.SOURCE

    @property
    def metadata(self) -> PluginMetadata:
        """Get plugin metadata."""
        return self._metadata

    @property
    def handler(self) -> CurriculumSourceHandler:
        """Access the underlying handler."""
        return self._handler

    # =========================================================================
    # Hook Implementations (delegate to handler)
    # =========================================================================

    @hookimpl
    def get_source_info(self) -> CurriculumSource:
        """Delegate to handler."""
        return self._handler.source_info

    @hookimpl
    def get_default_license(self) -> LicenseInfo:
        """Delegate to handler."""
        return self._handler.default_license

    @hookimpl
    async def get_course_catalog(
        self,
        page: int,
        page_size: int,
        filters: Optional[Dict[str, Any]],
        search: Optional[str],
    ) -> Tuple[List[CourseCatalogEntry], int, Dict[str, List[str]]]:
        """Delegate to handler."""
        return await self._handler.get_course_catalog(
            page=page,
            page_size=page_size,
            filters=filters,
            search=search,
        )

    @hookimpl
    async def get_course_detail(self, course_id: str) -> CourseDetail:
        """Delegate to handler."""
        return await self._handler.get_course_detail(course_id)

    @hookimpl
    async def download_course(
        self,
        course_id: str,
        output_dir: Path,
        progress_callback: Optional[Callable[[float, str], None]],
    ) -> Path:
        """Delegate to handler."""
        return await self._handler.download_course(
            course_id=course_id,
            output_dir=output_dir,
            progress_callback=progress_callback,
        )

    @hookimpl
    def validate_license(self, course_id: str) -> LicenseValidationResult:
        """Delegate to handler."""
        return self._handler.validate_license(course_id)


def wrap_legacy_handlers(
    handler_classes: List[Type[CurriculumSourceHandler]],
) -> List[LegacySourceAdapter]:
    """
    Wrap multiple legacy handler classes as plugins.

    Args:
        handler_classes: List of handler classes to wrap

    Returns:
        List of adapter plugins
    """
    adapters = []
    for handler_class in handler_classes:
        try:
            adapter = LegacySourceAdapter.from_handler_class(handler_class)
            adapters.append(adapter)
            logger.info(f"Wrapped legacy handler: {adapter.plugin_id}")
        except Exception as e:
            logger.error(f"Failed to wrap {handler_class.__name__}: {e}")
    return adapters


def discover_and_wrap_legacy_handlers() -> List[LegacySourceAdapter]:
    """
    Discover legacy handlers and wrap them as plugins.

    This imports from the sources module and wraps any
    CurriculumSourceHandler subclasses found.

    Returns:
        List of adapter plugins
    """
    adapters = []

    # Try to import MIT OCW handler
    try:
        from ..sources.mit_ocw import MITOCWHandler

        adapter = LegacySourceAdapter.from_handler_class(MITOCWHandler)
        adapters.append(adapter)
        logger.info("Wrapped legacy MIT OCW handler")
    except ImportError as e:
        logger.debug(f"MIT OCW handler not found: {e}")
    except Exception as e:
        logger.warning(f"Failed to wrap MIT OCW handler: {e}")

    # Add more handlers here as they're created
    # try:
    #     from ..sources.stanford_see import StanfordSEEHandler
    #     adapter = LegacySourceAdapter.from_handler_class(StanfordSEEHandler)
    #     adapters.append(adapter)
    # except ImportError:
    #     pass

    return adapters
