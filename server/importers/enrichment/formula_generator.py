"""
Formula Generator Service for curriculum imports.

Handles:
1. Validating LaTeX formula syntax
2. Generating fallback PNG/SVG images for clients that cannot render LaTeX
3. Providing placeholder images as a final fallback

This ensures curricula always have displayable mathematical content.
"""

import asyncio
import base64
import hashlib
import logging
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


class FormulaRenderMethod(Enum):
    """Method used to render the formula."""
    KATEX = "katex"          # KaTeX CLI
    LATEX = "latex"          # pdflatex + conversion
    PLACEHOLDER = "placeholder"  # Text-based SVG placeholder
    FAILED = "failed"        # All methods failed


@dataclass
class RenderedFormula:
    """Result of formula rendering."""
    success: bool
    render_method: FormulaRenderMethod
    data: Optional[bytes] = None
    mime_type: Optional[str] = None
    width: int = 0
    height: int = 0
    validation_errors: List[str] = field(default_factory=list)
    validation_warnings: List[str] = field(default_factory=list)
    error: Optional[str] = None


@dataclass
class FormulaSpec:
    """Specification for a formula to render."""
    id: str
    latex: str
    alt: Optional[str] = None
    display_mode: bool = True  # True for block, False for inline
    font_size: int = 18
    output_format: str = "svg"  # svg, png
    color: str = "#000000"
    background: str = "transparent"


class FormulaGenerator:
    """
    Service for generating formula images during curriculum import.

    Primary: Client-side rendering (LaTeX kept in UMCF)
    Fallback: Server-side PNG/SVG generation for clients that cannot render

    Attempts multiple strategies:
    1. KaTeX CLI (fastest, most common formulas)
    2. pdflatex + pdf2svg (comprehensive LaTeX support)
    3. Text-based SVG placeholder with alt text
    """

    # Common LaTeX errors
    LATEX_ERROR_PATTERNS = [
        (r"Undefined control sequence", "Unknown LaTeX command"),
        (r"Missing \$ inserted", "Math mode not properly delimited"),
        (r"Missing { inserted", "Unbalanced braces"),
        (r"Missing } inserted", "Unbalanced braces"),
        (r"Extra }", "Extra closing brace"),
        (r"Double superscript", "Cannot have two superscripts in a row"),
        (r"Double subscript", "Cannot have two subscripts in a row"),
    ]

    # Common LaTeX symbols that need math mode
    MATH_MODE_REQUIRED = [
        r"\\frac", r"\\sqrt", r"\\sum", r"\\int", r"\\prod",
        r"\\alpha", r"\\beta", r"\\gamma", r"\\delta", r"\\epsilon",
        r"\\theta", r"\\lambda", r"\\mu", r"\\pi", r"\\sigma",
        r"\\phi", r"\\omega", r"\\partial", r"\\nabla", r"\\infty",
    ]

    def __init__(
        self,
        cache_dir: Optional[Path] = None,
        katex_path: Optional[str] = None,
        latex_path: Optional[str] = None,
    ):
        self.cache_dir = cache_dir or Path("/tmp/unamentis_formula_cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Find rendering tools
        self.katex_path = katex_path or shutil.which("katex")
        self.latex_path = latex_path or shutil.which("pdflatex")
        self.pdf2svg_path = shutil.which("pdf2svg")

        self._katex_available = self.katex_path is not None
        self._latex_available = (
            self.latex_path is not None and self.pdf2svg_path is not None
        )

        if not self._katex_available and not self._latex_available:
            logger.warning(
                "Neither KaTeX nor pdflatex available. "
                "Formula rendering will use placeholders."
            )

    async def validate_latex(self, latex: str) -> Tuple[List[str], List[str]]:
        """
        Validate LaTeX formula syntax.

        Returns:
            Tuple of (errors, warnings)
        """
        errors = []
        warnings = []

        if not latex or not latex.strip():
            errors.append("Empty LaTeX formula")
            return errors, warnings

        # Check brace balance
        open_braces = latex.count("{")
        close_braces = latex.count("}")
        if open_braces != close_braces:
            errors.append(
                f"Unbalanced braces: {open_braces} opening, {close_braces} closing"
            )

        # Check for common issues
        if r"\frac" in latex and "{" not in latex:
            errors.append(r"\frac requires braces: \frac{numerator}{denominator}")

        # Check for math mode commands outside math mode
        for cmd in self.MATH_MODE_REQUIRED:
            if re.search(cmd, latex):
                # This is fine if they're using it in a formula context
                pass

        # Warn about potential issues
        if latex.startswith("$") or latex.endswith("$"):
            warnings.append(
                "LaTeX contains $ delimiters. UMCF expects raw LaTeX without delimiters."
            )

        if r"\begin{equation}" in latex:
            warnings.append(
                "Contains \\begin{equation}. Consider using displayMode instead."
            )

        return errors, warnings

    async def generate(self, spec: FormulaSpec) -> RenderedFormula:
        """
        Generate a rendered formula image.

        Args:
            spec: Formula specification

        Returns:
            RenderedFormula with image data or error
        """
        # Validate first
        errors, warnings = await self.validate_latex(spec.latex)

        if errors:
            return RenderedFormula(
                success=False,
                render_method=FormulaRenderMethod.FAILED,
                validation_errors=errors,
                validation_warnings=warnings,
                error="; ".join(errors),
            )

        # Try rendering methods in order
        result = None

        # Try KaTeX first (fastest)
        if self._katex_available:
            result = await self._render_with_katex(spec)
            if result.success:
                result.validation_warnings = warnings
                return result

        # Try pdflatex (more comprehensive)
        if self._latex_available:
            result = await self._render_with_latex(spec)
            if result.success:
                result.validation_warnings = warnings
                return result

        # Fall back to placeholder
        result = await self._generate_placeholder(spec)
        result.validation_warnings = warnings
        return result

    async def _render_with_katex(self, spec: FormulaSpec) -> RenderedFormula:
        """Render formula using KaTeX CLI."""
        try:
            # Build KaTeX command
            cmd = [
                self.katex_path,
                "--display-mode" if spec.display_mode else "",
                "--format", "html" if spec.output_format == "svg" else "htmlAndMathml",
            ]
            cmd = [c for c in cmd if c]  # Remove empty strings

            # Run KaTeX
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            stdout, stderr = await process.communicate(spec.latex.encode("utf-8"))

            if process.returncode != 0:
                error_msg = stderr.decode("utf-8", errors="replace")
                logger.debug(f"KaTeX rendering failed: {error_msg}")
                return RenderedFormula(
                    success=False,
                    render_method=FormulaRenderMethod.KATEX,
                    error=f"KaTeX error: {error_msg}",
                )

            # KaTeX outputs HTML, wrap in SVG using foreignObject
            html_content = stdout.decode("utf-8")
            svg_content = self._wrap_html_in_svg(html_content, spec)

            return RenderedFormula(
                success=True,
                render_method=FormulaRenderMethod.KATEX,
                data=svg_content.encode("utf-8"),
                mime_type="image/svg+xml",
                width=400,  # Estimated
                height=60 if spec.display_mode else 30,
            )

        except Exception as e:
            logger.debug(f"KaTeX rendering failed: {e}")
            return RenderedFormula(
                success=False,
                render_method=FormulaRenderMethod.KATEX,
                error=str(e),
            )

    async def _render_with_latex(self, spec: FormulaSpec) -> RenderedFormula:
        """Render formula using pdflatex + pdf2svg."""
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                tmppath = Path(tmpdir)

                # Create LaTeX document
                display_cmd = "displaystyle" if spec.display_mode else ""
                tex_content = rf"""
\documentclass[preview,border=2pt]{{standalone}}
\usepackage{{amsmath}}
\usepackage{{amssymb}}
\usepackage{{amsfonts}}
\usepackage{{xcolor}}
\begin{{document}}
\color[HTML]{{{spec.color.lstrip('#')}}}
$\{display_cmd} {spec.latex} $
\end{{document}}
"""
                tex_file = tmppath / "formula.tex"
                tex_file.write_text(tex_content)

                # Run pdflatex
                process = await asyncio.create_subprocess_exec(
                    self.latex_path,
                    "-interaction=nonstopmode",
                    "-output-directory", str(tmppath),
                    str(tex_file),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                await process.communicate()

                pdf_file = tmppath / "formula.pdf"
                if not pdf_file.exists():
                    return RenderedFormula(
                        success=False,
                        render_method=FormulaRenderMethod.LATEX,
                        error="pdflatex failed to produce PDF",
                    )

                # Convert PDF to SVG
                svg_file = tmppath / "formula.svg"
                process = await asyncio.create_subprocess_exec(
                    self.pdf2svg_path,
                    str(pdf_file),
                    str(svg_file),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                await process.communicate()

                if not svg_file.exists():
                    return RenderedFormula(
                        success=False,
                        render_method=FormulaRenderMethod.LATEX,
                        error="pdf2svg failed to convert PDF",
                    )

                svg_data = svg_file.read_bytes()

                return RenderedFormula(
                    success=True,
                    render_method=FormulaRenderMethod.LATEX,
                    data=svg_data,
                    mime_type="image/svg+xml",
                    width=400,
                    height=60 if spec.display_mode else 30,
                )

        except Exception as e:
            logger.debug(f"LaTeX rendering failed: {e}")
            return RenderedFormula(
                success=False,
                render_method=FormulaRenderMethod.LATEX,
                error=str(e),
            )

    async def _generate_placeholder(self, spec: FormulaSpec) -> RenderedFormula:
        """Generate a text-based SVG placeholder."""
        # Escape special characters for SVG
        escaped_latex = (
            spec.latex
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

        # Truncate if too long
        if len(escaped_latex) > 80:
            escaped_latex = escaped_latex[:77] + "..."

        alt_text = spec.alt or "Mathematical formula"
        escaped_alt = (
            alt_text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )

        height = 80 if spec.display_mode else 40
        svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="{height}" viewBox="0 0 400 {height}">
  <title>{escaped_alt}</title>
  <rect width="400" height="{height}" fill="#f8f9fa" rx="4"/>
  <text x="200" y="{height // 2 - 8}" text-anchor="middle" font-family="monospace" font-size="12" fill="#6c757d">
    {escaped_latex}
  </text>
  <text x="200" y="{height // 2 + 12}" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#adb5bd">
    (LaTeX formula - requires renderer)
  </text>
</svg>'''

        return RenderedFormula(
            success=True,
            render_method=FormulaRenderMethod.PLACEHOLDER,
            data=svg_content.encode("utf-8"),
            mime_type="image/svg+xml",
            width=400,
            height=height,
        )

    def _wrap_html_in_svg(self, html_content: str, spec: FormulaSpec) -> str:
        """Wrap KaTeX HTML output in SVG foreignObject."""
        height = 80 if spec.display_mode else 40
        return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="{height}">
  <foreignObject width="100%" height="100%">
    <div xmlns="http://www.w3.org/1999/xhtml" style="font-size: {spec.font_size}px;">
      {html_content}
    </div>
  </foreignObject>
</svg>'''

    def get_cache_path(self, spec: FormulaSpec) -> Path:
        """Get cache file path for a formula specification."""
        # Create hash of spec for cache key
        cache_key = hashlib.sha256(
            f"{spec.latex}:{spec.display_mode}:{spec.font_size}:{spec.output_format}".encode()
        ).hexdigest()[:16]
        return self.cache_dir / f"{cache_key}.{spec.output_format}"

    async def generate_with_cache(self, spec: FormulaSpec) -> RenderedFormula:
        """Generate formula with caching."""
        cache_path = self.get_cache_path(spec)

        # Check cache
        if cache_path.exists():
            try:
                data = cache_path.read_bytes()
                mime_type = (
                    "image/svg+xml" if spec.output_format == "svg" else "image/png"
                )
                return RenderedFormula(
                    success=True,
                    render_method=FormulaRenderMethod.KATEX,  # Assume cached
                    data=data,
                    mime_type=mime_type,
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
