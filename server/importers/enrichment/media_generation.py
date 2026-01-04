"""
Unified Media Generation Service for curriculum imports.

Coordinates generation of:
- Maps (static educational maps, interactive previews)
- Diagrams (Mermaid, Graphviz, PlantUML, D2)
- Formulas (LaTeX validation and fallback images)

This service is called during the enrichment phase to ensure all
generative media in the curriculum has been processed and has
appropriate fallback images for clients.
"""

import asyncio
import base64
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple

from .diagram_generator import (
    DiagramFormat,
    DiagramGenerator,
    DiagramSpec,
    RenderedDiagram,
)
from .formula_generator import (
    FormulaGenerator,
    FormulaSpec,
    RenderedFormula,
)
from .map_generator import (
    MapGenerator,
    MapMarker,
    MapRegion,
    MapRoute,
    MapSpec,
    MapStyle,
    RenderedMap,
)

logger = logging.getLogger(__name__)


@dataclass
class MediaGenerationConfig:
    """Configuration for media generation during import."""
    generate_maps: bool = True
    generate_diagrams: bool = True
    generate_formula_fallbacks: bool = True
    output_format: str = "png"  # png, svg
    cache_enabled: bool = True


@dataclass
class MediaGenerationStats:
    """Statistics from media generation run."""
    maps_processed: int = 0
    maps_succeeded: int = 0
    maps_failed: int = 0
    diagrams_processed: int = 0
    diagrams_succeeded: int = 0
    diagrams_failed: int = 0
    formulas_processed: int = 0
    formulas_valid: int = 0
    formulas_fallbacks_generated: int = 0
    formulas_failed: int = 0


@dataclass
class GeneratedMedia:
    """Result of generating a single media item."""
    id: str
    media_type: str  # map, diagram, formula
    success: bool
    data: Optional[bytes] = None
    mime_type: Optional[str] = None
    html_content: Optional[str] = None  # For interactive maps
    local_path: Optional[str] = None
    render_method: Optional[str] = None
    error: Optional[str] = None
    validation_warnings: List[str] = field(default_factory=list)


class MediaGenerationService:
    """
    Unified service for generating all types of educational media.

    Coordinates:
    - MapGenerator: Geographic content (static + interactive)
    - DiagramGenerator: Visual diagrams (Mermaid, Graphviz, etc.)
    - FormulaGenerator: LaTeX validation + fallback images

    Usage:
        service = MediaGenerationService(output_dir)
        results = await service.process_curriculum_media(content_nodes)
    """

    def __init__(
        self,
        output_dir: Path,
        config: Optional[MediaGenerationConfig] = None,
    ):
        """
        Initialize the media generation service.

        Args:
            output_dir: Directory for generated media files
            config: Configuration options
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.config = config or MediaGenerationConfig()

        # Initialize generators
        self.map_generator = MapGenerator(
            cache_dir=self.output_dir / "cache" / "maps"
        )
        self.diagram_generator = DiagramGenerator(
            cache_dir=self.output_dir / "cache" / "diagrams"
        )
        self.formula_generator = FormulaGenerator(
            cache_dir=self.output_dir / "cache" / "formulas"
        )

        # Output directories
        self.maps_dir = self.output_dir / "maps"
        self.diagrams_dir = self.output_dir / "diagrams"
        self.formulas_dir = self.output_dir / "formulas"

        for d in [self.maps_dir, self.diagrams_dir, self.formulas_dir]:
            d.mkdir(parents=True, exist_ok=True)

    async def process_curriculum_media(
        self,
        content_nodes: List[Dict[str, Any]],
        progress_callback: Optional[Callable[[str, float], None]] = None,
    ) -> Tuple[Dict[str, GeneratedMedia], MediaGenerationStats]:
        """
        Process all generative media in curriculum content nodes.

        Args:
            content_nodes: List of UMCF content nodes to process
            progress_callback: Optional callback for progress updates

        Returns:
            Tuple of (results dict keyed by media ID, statistics)
        """
        stats = MediaGenerationStats()
        results: Dict[str, GeneratedMedia] = {}

        # Collect all media items to process
        maps_to_process: List[Dict] = []
        diagrams_to_process: List[Dict] = []
        formulas_to_process: List[Dict] = []

        self._collect_media_from_nodes(
            content_nodes,
            maps_to_process,
            diagrams_to_process,
            formulas_to_process,
        )

        total_items = (
            len(maps_to_process) + len(diagrams_to_process) + len(formulas_to_process)
        )
        processed = 0

        def report_progress(item_type: str):
            nonlocal processed
            processed += 1
            if progress_callback:
                pct = (processed / total_items * 100) if total_items > 0 else 100
                progress_callback(item_type, pct)

        # Process maps
        if self.config.generate_maps and maps_to_process:
            for map_data in maps_to_process:
                result = await self._process_map(map_data)
                results[result.id] = result
                stats.maps_processed += 1
                if result.success:
                    stats.maps_succeeded += 1
                else:
                    stats.maps_failed += 1
                report_progress("map")

        # Process diagrams
        if self.config.generate_diagrams and diagrams_to_process:
            for diagram_data in diagrams_to_process:
                result = await self._process_diagram(diagram_data)
                results[result.id] = result
                stats.diagrams_processed += 1
                if result.success:
                    stats.diagrams_succeeded += 1
                else:
                    stats.diagrams_failed += 1
                report_progress("diagram")

        # Process formulas
        if self.config.generate_formula_fallbacks and formulas_to_process:
            for formula_data in formulas_to_process:
                result = await self._process_formula(formula_data)
                results[result.id] = result
                stats.formulas_processed += 1
                if result.success:
                    stats.formulas_valid += 1
                    if result.data:
                        stats.formulas_fallbacks_generated += 1
                else:
                    stats.formulas_failed += 1
                report_progress("formula")

        return results, stats

    def _collect_media_from_nodes(
        self,
        nodes: List[Dict[str, Any]],
        maps: List[Dict],
        diagrams: List[Dict],
        formulas: List[Dict],
    ):
        """Recursively collect media items from content nodes."""
        for node in nodes:
            # Check media collection in node
            media = node.get("media", {})

            # Embedded media
            for embedded in media.get("embedded", []):
                media_type = embedded.get("type")
                if media_type == "map":
                    maps.append(embedded)
                elif media_type == "diagram":
                    # Check if diagram has source code that needs rendering
                    if embedded.get("sourceCode"):
                        diagrams.append(embedded)
                elif media_type in ("formula", "equation"):
                    if embedded.get("latex"):
                        formulas.append(embedded)

            # Check generativeMedia collection (new UMCF 1.1 format)
            gen_media = node.get("generativeMedia", {})
            maps.extend(gen_media.get("maps", []))
            diagrams.extend(gen_media.get("diagrams", []))
            formulas.extend(gen_media.get("formulas", []))

            # Recurse into children
            children = node.get("children", [])
            if children:
                self._collect_media_from_nodes(children, maps, diagrams, formulas)

    async def _process_map(self, map_data: Dict) -> GeneratedMedia:
        """Process a single map specification."""
        map_id = map_data.get("id", f"map-{id(map_data)}")

        try:
            # Extract geography
            geography = map_data.get("geography", {})
            center = geography.get("center", {})

            # Parse markers
            markers = []
            for m in map_data.get("markers", []):
                markers.append(MapMarker(
                    latitude=m.get("latitude", 0),
                    longitude=m.get("longitude", 0),
                    label=m.get("label", ""),
                    icon=m.get("icon"),
                    color=m.get("color", "#E74C3C"),
                    popup=m.get("popup"),
                ))

            # Parse routes
            routes = []
            for r in map_data.get("routes", []):
                points = [tuple(p) for p in r.get("points", [])]
                routes.append(MapRoute(
                    points=points,
                    label=r.get("label", ""),
                    color=r.get("color", "#3498DB"),
                    width=r.get("width", 2.0),
                    style=r.get("style", "solid"),
                ))

            # Parse regions
            regions = []
            for rg in map_data.get("regions", []):
                points = [tuple(p) for p in rg.get("points", [])]
                regions.append(MapRegion(
                    points=points,
                    label=rg.get("label", ""),
                    fill_color=rg.get("fillColor", "#3498DB"),
                    fill_opacity=rg.get("fillOpacity", 0.3),
                    border_color=rg.get("borderColor", "#2980B9"),
                    border_width=rg.get("borderWidth", 1.0),
                ))

            # Map style
            style_str = map_data.get("mapStyle", "educational")
            style = MapStyle.EDUCATIONAL
            for s in MapStyle:
                if s.value == style_str.lower():
                    style = s
                    break

            # Time period
            time_period = None
            tp = map_data.get("timePeriod")
            if tp:
                time_period = tp.get("displayLabel") or str(tp.get("year", ""))

            spec = MapSpec(
                id=map_id,
                title=map_data.get("title", "Map"),
                center_latitude=center.get("latitude", 0),
                center_longitude=center.get("longitude", 0),
                zoom=geography.get("zoom", 5),
                width=map_data.get("width", 800),
                height=map_data.get("height", 600),
                style=style,
                markers=markers,
                routes=routes,
                regions=regions,
                time_period=time_period,
                language=map_data.get("language", "en"),
                output_format=self.config.output_format,
                interactive=map_data.get("interactive", False),
            )

            # Generate
            if self.config.cache_enabled:
                result = await self.map_generator.generate_with_cache(spec)
            else:
                result = await self.map_generator.generate(spec)

            if result.success:
                # Save to file
                local_path = None
                if result.data:
                    ext = "svg" if result.mime_type == "image/svg+xml" else "png"
                    file_path = self.maps_dir / f"{map_id}.{ext}"
                    file_path.write_bytes(result.data)
                    local_path = str(file_path)
                elif result.html_content:
                    file_path = self.maps_dir / f"{map_id}.html"
                    file_path.write_text(result.html_content)
                    local_path = str(file_path)

                return GeneratedMedia(
                    id=map_id,
                    media_type="map",
                    success=True,
                    data=result.data,
                    mime_type=result.mime_type,
                    html_content=result.html_content,
                    local_path=local_path,
                    render_method=result.render_method.value,
                )
            else:
                return GeneratedMedia(
                    id=map_id,
                    media_type="map",
                    success=False,
                    error=result.error,
                    render_method=result.render_method.value if result.render_method else None,
                )

        except Exception as e:
            logger.error(f"Failed to process map {map_id}: {e}")
            return GeneratedMedia(
                id=map_id,
                media_type="map",
                success=False,
                error=str(e),
            )

    async def _process_diagram(self, diagram_data: Dict) -> GeneratedMedia:
        """Process a single diagram specification."""
        diagram_id = diagram_data.get("id", f"diagram-{id(diagram_data)}")

        try:
            source_code = diagram_data.get("sourceCode", {})
            format_str = source_code.get("format", "mermaid")

            # Map format string to enum
            format_map = {
                "mermaid": DiagramFormat.MERMAID,
                "graphviz": DiagramFormat.GRAPHVIZ,
                "dot": DiagramFormat.GRAPHVIZ,
                "plantuml": DiagramFormat.PLANTUML,
                "d2": DiagramFormat.D2,
            }
            diagram_format = format_map.get(format_str.lower(), DiagramFormat.MERMAID)

            spec = DiagramSpec(
                id=diagram_id,
                code=source_code.get("code", ""),
                format=diagram_format,
                title=diagram_data.get("title"),
                alt=diagram_data.get("alt"),
                width=diagram_data.get("width", 800),
                height=diagram_data.get("height", 600),
                theme=diagram_data.get("theme", "default"),
                background=diagram_data.get("background", "white"),
                output_format=self.config.output_format,
            )

            # Validate first
            errors = await self.diagram_generator.validate(spec)
            if errors:
                return GeneratedMedia(
                    id=diagram_id,
                    media_type="diagram",
                    success=False,
                    error="; ".join(errors),
                )

            # Generate
            if self.config.cache_enabled:
                result = await self.diagram_generator.generate_with_cache(spec)
            else:
                result = await self.diagram_generator.generate(spec)

            if result.success:
                # Save to file
                ext = "svg" if result.mime_type == "image/svg+xml" else "png"
                file_path = self.diagrams_dir / f"{diagram_id}.{ext}"
                file_path.write_bytes(result.data)

                return GeneratedMedia(
                    id=diagram_id,
                    media_type="diagram",
                    success=True,
                    data=result.data,
                    mime_type=result.mime_type,
                    local_path=str(file_path),
                    render_method=result.render_method.value,
                    validation_warnings=result.validation_warnings,
                )
            else:
                return GeneratedMedia(
                    id=diagram_id,
                    media_type="diagram",
                    success=False,
                    error=result.error,
                    render_method=result.render_method.value if result.render_method else None,
                )

        except Exception as e:
            logger.error(f"Failed to process diagram {diagram_id}: {e}")
            return GeneratedMedia(
                id=diagram_id,
                media_type="diagram",
                success=False,
                error=str(e),
            )

    async def _process_formula(self, formula_data: Dict) -> GeneratedMedia:
        """Process a single formula specification."""
        formula_id = formula_data.get("id", f"formula-{id(formula_data)}")

        try:
            latex = formula_data.get("latex", "")
            if not latex:
                return GeneratedMedia(
                    id=formula_id,
                    media_type="formula",
                    success=False,
                    error="No LaTeX content",
                )

            spec = FormulaSpec(
                id=formula_id,
                latex=latex,
                alt=formula_data.get("alt"),
                display_mode=formula_data.get("displayMode", "block") == "block",
                font_size=formula_data.get("fontSize", 18),
                output_format=self.config.output_format,
                color=formula_data.get("color", "#000000"),
                background=formula_data.get("background", "transparent"),
            )

            # Generate (always generates fallback image)
            if self.config.cache_enabled:
                result = await self.formula_generator.generate_with_cache(spec)
            else:
                result = await self.formula_generator.generate(spec)

            if result.success:
                # Save fallback image
                ext = "svg" if result.mime_type == "image/svg+xml" else "png"
                file_path = self.formulas_dir / f"{formula_id}.{ext}"
                file_path.write_bytes(result.data)

                return GeneratedMedia(
                    id=formula_id,
                    media_type="formula",
                    success=True,
                    data=result.data,
                    mime_type=result.mime_type,
                    local_path=str(file_path),
                    render_method=result.render_method.value,
                    validation_warnings=result.validation_warnings,
                )
            else:
                return GeneratedMedia(
                    id=formula_id,
                    media_type="formula",
                    success=False,
                    error=result.error,
                    validation_warnings=result.validation_errors,
                )

        except Exception as e:
            logger.error(f"Failed to process formula {formula_id}: {e}")
            return GeneratedMedia(
                id=formula_id,
                media_type="formula",
                success=False,
                error=str(e),
            )

    async def process_single_map(self, map_data: Dict) -> GeneratedMedia:
        """Process a single map (public API)."""
        return await self._process_map(map_data)

    async def process_single_diagram(self, diagram_data: Dict) -> GeneratedMedia:
        """Process a single diagram (public API)."""
        return await self._process_diagram(diagram_data)

    async def process_single_formula(self, formula_data: Dict) -> GeneratedMedia:
        """Process a single formula (public API)."""
        return await self._process_formula(formula_data)

    def get_generated_assets(self) -> Dict[str, List[Path]]:
        """Get all generated asset files organized by type."""
        return {
            "maps": list(self.maps_dir.glob("*")),
            "diagrams": list(self.diagrams_dir.glob("*")),
            "formulas": list(self.formulas_dir.glob("*")),
        }

    async def close(self):
        """Clean up resources."""
        await self.map_generator.close()
        await self.diagram_generator.close()
        await self.formula_generator.close()
