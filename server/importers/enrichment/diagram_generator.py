"""
Diagram Generator Service for curriculum imports.

Handles:
1. Rendering Mermaid diagrams to SVG/PNG
2. Rendering Graphviz (DOT) diagrams to SVG/PNG
3. Generating placeholder diagrams as a final fallback

This ensures curricula always have displayable diagram content.
"""

import asyncio
import base64
import hashlib
import logging
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class DiagramFormat(Enum):
    """Diagram source format."""
    MERMAID = "mermaid"
    GRAPHVIZ = "graphviz"
    PLANTUML = "plantuml"
    D2 = "d2"
    SVG_RAW = "svg-raw"


class DiagramRenderMethod(Enum):
    """Method used to render the diagram."""
    MERMAID_CLI = "mermaid_cli"  # mermaid-cli (mmdc)
    GRAPHVIZ = "graphviz"        # dot command
    PLANTUML = "plantuml"        # plantuml.jar
    D2 = "d2"                    # d2 CLI
    PASSTHROUGH = "passthrough"  # SVG passed through
    PLACEHOLDER = "placeholder"  # Generated placeholder
    FAILED = "failed"            # All methods failed


@dataclass
class RenderedDiagram:
    """Result of diagram rendering."""
    success: bool
    render_method: DiagramRenderMethod
    data: Optional[bytes] = None
    mime_type: Optional[str] = None
    width: int = 0
    height: int = 0
    validation_errors: List[str] = field(default_factory=list)
    error: Optional[str] = None


@dataclass
class DiagramSpec:
    """Specification for a diagram to render."""
    id: str
    title: str
    source_format: DiagramFormat
    source_code: str
    output_format: str = "svg"  # svg, png
    theme: str = "default"
    width: Optional[int] = None
    height: Optional[int] = None
    background: str = "transparent"
    alt: Optional[str] = None


class DiagramGenerator:
    """
    Service for generating diagram images during curriculum import.

    Supports:
    1. Mermaid diagrams (flowchart, sequence, class, state, etc.)
    2. Graphviz DOT diagrams (graphs, trees, networks)
    3. PlantUML diagrams (UML)
    4. D2 diagrams (modern declarative)

    Falls back to placeholder SVG if rendering fails.
    """

    # Mermaid themes
    MERMAID_THEMES = {
        "default": "default",
        "dark": "dark",
        "forest": "forest",
        "neutral": "neutral",
    }

    def __init__(
        self,
        cache_dir: Optional[Path] = None,
        mermaid_path: Optional[str] = None,
        graphviz_path: Optional[str] = None,
        plantuml_path: Optional[str] = None,
        d2_path: Optional[str] = None,
    ):
        self.cache_dir = cache_dir or Path("/tmp/unamentis_diagram_cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Find rendering tools
        self.mermaid_path = mermaid_path or shutil.which("mmdc")
        self.graphviz_path = graphviz_path or shutil.which("dot")
        self.plantuml_path = plantuml_path or shutil.which("plantuml")
        self.d2_path = d2_path or shutil.which("d2")

        self._mermaid_available = self.mermaid_path is not None
        self._graphviz_available = self.graphviz_path is not None
        self._plantuml_available = self.plantuml_path is not None
        self._d2_available = self.d2_path is not None

        available = []
        if self._mermaid_available:
            available.append("Mermaid")
        if self._graphviz_available:
            available.append("Graphviz")
        if self._plantuml_available:
            available.append("PlantUML")
        if self._d2_available:
            available.append("D2")

        if available:
            logger.info(f"Diagram generators available: {', '.join(available)}")
        else:
            logger.warning(
                "No diagram generators available. "
                "Diagram rendering will use placeholders. "
                "Install: npm i -g @mermaid-js/mermaid-cli, brew install graphviz"
            )

    async def validate(self, spec: DiagramSpec) -> List[str]:
        """
        Validate diagram source code.

        Returns:
            List of validation errors (empty if valid)
        """
        errors = []

        if not spec.source_code or not spec.source_code.strip():
            errors.append("Empty diagram source code")
            return errors

        # Format-specific validation
        if spec.source_format == DiagramFormat.MERMAID:
            errors.extend(self._validate_mermaid(spec.source_code))
        elif spec.source_format == DiagramFormat.GRAPHVIZ:
            errors.extend(self._validate_graphviz(spec.source_code))

        return errors

    def _validate_mermaid(self, code: str) -> List[str]:
        """Validate Mermaid diagram syntax."""
        errors = []

        # Check for diagram type declaration
        valid_types = [
            "graph", "flowchart", "sequenceDiagram", "classDiagram",
            "stateDiagram", "erDiagram", "gantt", "pie", "journey",
            "gitGraph", "mindmap", "timeline", "quadrantChart",
        ]

        first_line = code.strip().split("\n")[0].strip()
        has_valid_type = any(first_line.startswith(t) for t in valid_types)

        if not has_valid_type:
            errors.append(
                f"Mermaid diagram should start with a valid type. "
                f"Found: '{first_line[:30]}...'. "
                f"Valid types: {', '.join(valid_types[:5])}..."
            )

        return errors

    def _validate_graphviz(self, code: str) -> List[str]:
        """Validate Graphviz DOT syntax."""
        errors = []

        # Check for graph declaration
        if not any(kw in code for kw in ["digraph", "graph", "subgraph"]):
            errors.append(
                "Graphviz code should contain 'digraph', 'graph', or 'subgraph'"
            )

        # Check brace balance
        if code.count("{") != code.count("}"):
            errors.append("Unbalanced braces in Graphviz code")

        return errors

    async def generate(self, spec: DiagramSpec) -> RenderedDiagram:
        """
        Generate a rendered diagram image.

        Args:
            spec: Diagram specification

        Returns:
            RenderedDiagram with image data or error
        """
        # Validate first
        errors = await self.validate(spec)
        if errors:
            return RenderedDiagram(
                success=False,
                render_method=DiagramRenderMethod.FAILED,
                validation_errors=errors,
                error="; ".join(errors),
            )

        # Route to appropriate renderer
        if spec.source_format == DiagramFormat.SVG_RAW:
            return self._passthrough_svg(spec)

        if spec.source_format == DiagramFormat.MERMAID:
            if self._mermaid_available:
                result = await self._render_mermaid(spec)
                if result.success:
                    return result
            # Fall back to Graphviz if mermaid unavailable
            # (can't convert, so fall through to placeholder)

        elif spec.source_format == DiagramFormat.GRAPHVIZ:
            if self._graphviz_available:
                result = await self._render_graphviz(spec)
                if result.success:
                    return result

        elif spec.source_format == DiagramFormat.PLANTUML:
            if self._plantuml_available:
                result = await self._render_plantuml(spec)
                if result.success:
                    return result

        elif spec.source_format == DiagramFormat.D2:
            if self._d2_available:
                result = await self._render_d2(spec)
                if result.success:
                    return result

        # Fall back to placeholder
        return await self._generate_placeholder(spec)

    def _passthrough_svg(self, spec: DiagramSpec) -> RenderedDiagram:
        """Pass through raw SVG content."""
        return RenderedDiagram(
            success=True,
            render_method=DiagramRenderMethod.PASSTHROUGH,
            data=spec.source_code.encode("utf-8"),
            mime_type="image/svg+xml",
            width=spec.width or 400,
            height=spec.height or 300,
        )

    async def _render_mermaid(self, spec: DiagramSpec) -> RenderedDiagram:
        """Render Mermaid diagram using mmdc CLI."""
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                tmppath = Path(tmpdir)
                input_file = tmppath / "diagram.mmd"
                output_file = tmppath / f"diagram.{spec.output_format}"

                # Write source to file
                input_file.write_text(spec.source_code)

                # Build mmdc command
                cmd = [
                    self.mermaid_path,
                    "-i", str(input_file),
                    "-o", str(output_file),
                    "-t", self.MERMAID_THEMES.get(spec.theme, "default"),
                    "-b", spec.background,
                ]

                if spec.width:
                    cmd.extend(["-w", str(spec.width)])
                if spec.height:
                    cmd.extend(["-H", str(spec.height)])

                # Run mmdc
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                stdout, stderr = await process.communicate()

                if process.returncode != 0:
                    error_msg = stderr.decode("utf-8", errors="replace")
                    logger.debug(f"Mermaid rendering failed: {error_msg}")
                    return RenderedDiagram(
                        success=False,
                        render_method=DiagramRenderMethod.MERMAID_CLI,
                        error=f"Mermaid error: {error_msg[:200]}",
                    )

                if not output_file.exists():
                    return RenderedDiagram(
                        success=False,
                        render_method=DiagramRenderMethod.MERMAID_CLI,
                        error="Mermaid did not produce output file",
                    )

                data = output_file.read_bytes()
                mime_type = (
                    "image/svg+xml" if spec.output_format == "svg" else "image/png"
                )

                return RenderedDiagram(
                    success=True,
                    render_method=DiagramRenderMethod.MERMAID_CLI,
                    data=data,
                    mime_type=mime_type,
                    width=spec.width or 400,
                    height=spec.height or 300,
                )

        except Exception as e:
            logger.debug(f"Mermaid rendering failed: {e}")
            return RenderedDiagram(
                success=False,
                render_method=DiagramRenderMethod.MERMAID_CLI,
                error=str(e),
            )

    async def _render_graphviz(self, spec: DiagramSpec) -> RenderedDiagram:
        """Render Graphviz diagram using dot command."""
        try:
            output_format = "svg" if spec.output_format == "svg" else "png"

            process = await asyncio.create_subprocess_exec(
                self.graphviz_path,
                f"-T{output_format}",
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            stdout, stderr = await process.communicate(spec.source_code.encode("utf-8"))

            if process.returncode != 0:
                error_msg = stderr.decode("utf-8", errors="replace")
                logger.debug(f"Graphviz rendering failed: {error_msg}")
                return RenderedDiagram(
                    success=False,
                    render_method=DiagramRenderMethod.GRAPHVIZ,
                    error=f"Graphviz error: {error_msg[:200]}",
                )

            mime_type = (
                "image/svg+xml" if output_format == "svg" else "image/png"
            )

            return RenderedDiagram(
                success=True,
                render_method=DiagramRenderMethod.GRAPHVIZ,
                data=stdout,
                mime_type=mime_type,
                width=spec.width or 400,
                height=spec.height or 300,
            )

        except Exception as e:
            logger.debug(f"Graphviz rendering failed: {e}")
            return RenderedDiagram(
                success=False,
                render_method=DiagramRenderMethod.GRAPHVIZ,
                error=str(e),
            )

    async def _render_plantuml(self, spec: DiagramSpec) -> RenderedDiagram:
        """Render PlantUML diagram."""
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                tmppath = Path(tmpdir)
                input_file = tmppath / "diagram.puml"
                input_file.write_text(spec.source_code)

                output_format = "svg" if spec.output_format == "svg" else "png"

                process = await asyncio.create_subprocess_exec(
                    self.plantuml_path,
                    f"-t{output_format}",
                    "-o", str(tmppath),
                    str(input_file),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                await process.communicate()

                output_file = tmppath / f"diagram.{output_format}"
                if not output_file.exists():
                    return RenderedDiagram(
                        success=False,
                        render_method=DiagramRenderMethod.PLANTUML,
                        error="PlantUML did not produce output file",
                    )

                data = output_file.read_bytes()
                mime_type = (
                    "image/svg+xml" if output_format == "svg" else "image/png"
                )

                return RenderedDiagram(
                    success=True,
                    render_method=DiagramRenderMethod.PLANTUML,
                    data=data,
                    mime_type=mime_type,
                    width=spec.width or 400,
                    height=spec.height or 300,
                )

        except Exception as e:
            logger.debug(f"PlantUML rendering failed: {e}")
            return RenderedDiagram(
                success=False,
                render_method=DiagramRenderMethod.PLANTUML,
                error=str(e),
            )

    async def _render_d2(self, spec: DiagramSpec) -> RenderedDiagram:
        """Render D2 diagram."""
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                tmppath = Path(tmpdir)
                input_file = tmppath / "diagram.d2"
                output_file = tmppath / f"diagram.{spec.output_format}"

                input_file.write_text(spec.source_code)

                cmd = [
                    self.d2_path,
                    str(input_file),
                    str(output_file),
                ]

                if spec.theme and spec.theme != "default":
                    cmd.extend(["--theme", spec.theme])

                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                stdout, stderr = await process.communicate()

                if process.returncode != 0 or not output_file.exists():
                    error_msg = stderr.decode("utf-8", errors="replace")
                    return RenderedDiagram(
                        success=False,
                        render_method=DiagramRenderMethod.D2,
                        error=f"D2 error: {error_msg[:200]}",
                    )

                data = output_file.read_bytes()
                mime_type = (
                    "image/svg+xml" if spec.output_format == "svg" else "image/png"
                )

                return RenderedDiagram(
                    success=True,
                    render_method=DiagramRenderMethod.D2,
                    data=data,
                    mime_type=mime_type,
                    width=spec.width or 400,
                    height=spec.height or 300,
                )

        except Exception as e:
            logger.debug(f"D2 rendering failed: {e}")
            return RenderedDiagram(
                success=False,
                render_method=DiagramRenderMethod.D2,
                error=str(e),
            )

    async def _generate_placeholder(self, spec: DiagramSpec) -> RenderedDiagram:
        """Generate a placeholder SVG showing diagram source code."""
        # Escape special characters for SVG
        escaped_code = (
            spec.source_code[:200]
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )
        if len(spec.source_code) > 200:
            escaped_code += "..."

        # Replace newlines with SVG line breaks
        lines = escaped_code.split("\n")[:10]

        title = spec.title or "Diagram"
        escaped_title = title.replace("&", "&amp;").replace("<", "&lt;")

        format_name = spec.source_format.value.capitalize()

        height = max(200, len(lines) * 18 + 80)
        width = spec.width or 400

        # Build text elements for each line
        text_elements = []
        for i, line in enumerate(lines):
            y = 70 + i * 18
            text_elements.append(
                f'<text x="20" y="{y}" font-family="monospace" font-size="11" fill="#495057">{line}</text>'
            )

        text_content = "\n    ".join(text_elements)

        svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <title>{escaped_title}</title>
  <rect width="{width}" height="{height}" fill="#f8f9fa" rx="8"/>
  <rect x="10" y="10" width="{width - 20}" height="35" fill="#e9ecef" rx="4"/>
  <text x="20" y="32" font-family="sans-serif" font-size="14" font-weight="bold" fill="#343a40">{escaped_title}</text>
  <text x="{width - 20}" y="32" text-anchor="end" font-family="sans-serif" font-size="11" fill="#6c757d">{format_name}</text>
  <line x1="10" y1="55" x2="{width - 10}" y2="55" stroke="#dee2e6" stroke-width="1"/>
    {text_content}
  <text x="{width // 2}" y="{height - 15}" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#adb5bd">
    (Diagram placeholder - renderer not available)
  </text>
</svg>'''

        return RenderedDiagram(
            success=True,
            render_method=DiagramRenderMethod.PLACEHOLDER,
            data=svg_content.encode("utf-8"),
            mime_type="image/svg+xml",
            width=width,
            height=height,
        )

    def get_cache_path(self, spec: DiagramSpec) -> Path:
        """Get cache file path for a diagram specification."""
        cache_key = hashlib.sha256(
            f"{spec.source_format.value}:{spec.source_code}:{spec.theme}".encode()
        ).hexdigest()[:16]
        return self.cache_dir / f"{cache_key}.{spec.output_format}"

    async def generate_with_cache(self, spec: DiagramSpec) -> RenderedDiagram:
        """Generate diagram with caching."""
        cache_path = self.get_cache_path(spec)

        # Check cache
        if cache_path.exists():
            try:
                data = cache_path.read_bytes()
                mime_type = (
                    "image/svg+xml" if spec.output_format == "svg" else "image/png"
                )
                return RenderedDiagram(
                    success=True,
                    render_method=DiagramRenderMethod.MERMAID_CLI,  # Assume cached
                    data=data,
                    mime_type=mime_type,
                    width=spec.width or 400,
                    height=spec.height or 300,
                )
            except Exception as e:
                logger.debug(f"Cache read failed: {e}")

        # Generate
        result = await self.generate(spec)

        # Cache successful results
        if result.success and result.data:
            try:
                cache_path.write_bytes(result.data)
            except Exception as e:
                logger.debug(f"Cache write failed: {e}")

        return result

    async def close(self):
        """Clean up resources."""
        pass
