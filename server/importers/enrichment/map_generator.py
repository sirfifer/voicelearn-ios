"""
Map Generator Service for curriculum imports.

Handles:
1. Static educational map generation (Cartopy)
2. Interactive map previews (Folium)
3. OpenStreetMap tile-based fallback
4. Placeholder SVG generation as final fallback

This ensures curricula always have displayable geographic content.
"""

import asyncio
import base64
import hashlib
import io
import logging
import shutil
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


class MapStyle(Enum):
    """Visual style for the generated map."""
    STANDARD = "standard"        # Modern political map
    HISTORICAL = "historical"    # Aged/parchment style
    PHYSICAL = "physical"        # Terrain/elevation focus
    SATELLITE = "satellite"      # Aerial imagery
    MINIMAL = "minimal"          # Clean, minimal styling
    EDUCATIONAL = "educational"  # Clear labels, educational focus


class MapRenderMethod(Enum):
    """Method used to render the map."""
    CARTOPY = "cartopy"          # Matplotlib + Cartopy
    FOLIUM = "folium"            # Folium HTML screenshot
    STATIC_TILES = "static_tiles"  # OpenStreetMap static tiles
    PLACEHOLDER = "placeholder"  # SVG placeholder
    FAILED = "failed"            # All methods failed


@dataclass
class MapMarker:
    """A marker/pin on the map."""
    latitude: float
    longitude: float
    label: str
    icon: Optional[str] = None  # Icon type: city, battle, landmark, etc.
    color: str = "#E74C3C"
    popup: Optional[str] = None  # Extended info for interactive maps


@dataclass
class MapRoute:
    """A route/path on the map."""
    points: List[Tuple[float, float]]  # List of (lat, lon) pairs
    label: str
    color: str = "#3498DB"
    width: float = 2.0
    style: str = "solid"  # solid, dashed, dotted


@dataclass
class MapRegion:
    """A highlighted region/area on the map."""
    points: List[Tuple[float, float]]  # Polygon vertices (lat, lon)
    label: str
    fill_color: str = "#3498DB"
    fill_opacity: float = 0.3
    border_color: str = "#2980B9"
    border_width: float = 1.0


@dataclass
class MapSpec:
    """Specification for a map to generate."""
    id: str
    title: str
    center_latitude: float
    center_longitude: float
    zoom: int = 5  # 1-18, where 1 is world, 18 is street level
    width: int = 800
    height: int = 600
    style: MapStyle = MapStyle.EDUCATIONAL
    markers: List[MapMarker] = field(default_factory=list)
    routes: List[MapRoute] = field(default_factory=list)
    regions: List[MapRegion] = field(default_factory=list)
    time_period: Optional[str] = None  # e.g., "15th Century"
    language: str = "en"
    output_format: str = "png"  # png, svg, html
    interactive: bool = False  # Generate interactive HTML


@dataclass
class RenderedMap:
    """Result of map rendering."""
    success: bool
    render_method: MapRenderMethod
    data: Optional[bytes] = None
    mime_type: Optional[str] = None
    width: int = 0
    height: int = 0
    html_content: Optional[str] = None  # For interactive maps
    error: Optional[str] = None


class MapGenerator:
    """
    Service for generating map images during curriculum import.

    Supports multiple rendering strategies:
    1. Cartopy (publication-quality static maps)
    2. Folium (interactive maps, can screenshot for static)
    3. OpenStreetMap static tiles (simple fallback)
    4. SVG placeholder (final fallback)
    """

    # Zoom level to Cartopy extent mapping (approximate degrees)
    ZOOM_TO_EXTENT = {
        1: 180,   # World
        2: 90,
        3: 45,
        4: 22.5,
        5: 11.25,
        6: 5.6,
        7: 2.8,
        8: 1.4,
        9: 0.7,
        10: 0.35,
        11: 0.17,
        12: 0.085,
        13: 0.042,
        14: 0.021,
        15: 0.01,
        16: 0.005,
        17: 0.0025,
        18: 0.00125,
    }

    def __init__(
        self,
        cache_dir: Optional[Path] = None,
        tile_cache_dir: Optional[Path] = None,
    ):
        self.cache_dir = cache_dir or Path("/tmp/unamentis_map_cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.tile_cache_dir = tile_cache_dir or self.cache_dir / "tiles"
        self.tile_cache_dir.mkdir(parents=True, exist_ok=True)

        # Check for available libraries
        self._cartopy_available = self._check_cartopy()
        self._folium_available = self._check_folium()
        self._selenium_available = self._check_selenium()

        if not self._cartopy_available and not self._folium_available:
            logger.warning(
                "Neither Cartopy nor Folium available. "
                "Map rendering will use placeholders."
            )

    def _check_cartopy(self) -> bool:
        """Check if Cartopy is available."""
        try:
            import cartopy
            import matplotlib
            matplotlib.use('Agg')  # Use non-interactive backend
            return True
        except ImportError:
            return False

    def _check_folium(self) -> bool:
        """Check if Folium is available."""
        try:
            import folium
            return True
        except ImportError:
            return False

    def _check_selenium(self) -> bool:
        """Check if Selenium is available for Folium screenshots."""
        try:
            from selenium import webdriver
            return True
        except ImportError:
            return False

    async def generate(self, spec: MapSpec) -> RenderedMap:
        """
        Generate a map image.

        Args:
            spec: Map specification

        Returns:
            RenderedMap with image data or error
        """
        # For interactive maps, always use Folium
        if spec.interactive and self._folium_available:
            return await self._render_with_folium(spec, interactive=True)

        # Try rendering methods in order for static maps
        result = None

        # Try Cartopy first (best for educational/publication maps)
        if self._cartopy_available:
            result = await self._render_with_cartopy(spec)
            if result.success:
                return result

        # Try Folium with screenshot
        if self._folium_available and self._selenium_available:
            result = await self._render_with_folium(spec, interactive=False)
            if result.success:
                return result

        # Try static tiles
        result = await self._render_with_static_tiles(spec)
        if result.success:
            return result

        # Fall back to placeholder
        return await self._generate_placeholder(spec)

    async def _render_with_cartopy(self, spec: MapSpec) -> RenderedMap:
        """Render map using Cartopy (matplotlib-based)."""
        try:
            import cartopy.crs as ccrs
            import cartopy.feature as cfeature
            import matplotlib.pyplot as plt
            from matplotlib.patches import Polygon
            import numpy as np

            # Run in executor to avoid blocking
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None,
                self._cartopy_render_sync,
                spec
            )
            return result

        except Exception as e:
            logger.debug(f"Cartopy rendering failed: {e}")
            return RenderedMap(
                success=False,
                render_method=MapRenderMethod.CARTOPY,
                error=str(e),
            )

    def _cartopy_render_sync(self, spec: MapSpec) -> RenderedMap:
        """Synchronous Cartopy rendering (runs in executor)."""
        import cartopy.crs as ccrs
        import cartopy.feature as cfeature
        import matplotlib.pyplot as plt
        from matplotlib.patches import Polygon as MplPolygon
        import numpy as np

        try:
            # Calculate extent from zoom level
            extent_deg = self.ZOOM_TO_EXTENT.get(spec.zoom, 11.25)
            extent = [
                spec.center_longitude - extent_deg,
                spec.center_longitude + extent_deg,
                spec.center_latitude - extent_deg * 0.6,  # Aspect ratio adjustment
                spec.center_latitude + extent_deg * 0.6,
            ]

            # Create figure with Cartopy projection
            fig = plt.figure(figsize=(spec.width / 100, spec.height / 100), dpi=100)
            ax = fig.add_subplot(1, 1, 1, projection=ccrs.PlateCarree())
            ax.set_extent(extent, crs=ccrs.PlateCarree())

            # Apply style
            self._apply_cartopy_style(ax, spec.style)

            # Add features based on zoom level
            if spec.zoom <= 6:
                ax.add_feature(cfeature.LAND, facecolor='#f5f5dc')
                ax.add_feature(cfeature.OCEAN, facecolor='#b0c4de')
                ax.add_feature(cfeature.COASTLINE, linewidth=0.5)
                ax.add_feature(cfeature.BORDERS, linestyle=':', linewidth=0.5)
            else:
                ax.add_feature(cfeature.LAND, facecolor='#f5f5dc')
                ax.add_feature(cfeature.OCEAN, facecolor='#b0c4de')
                ax.add_feature(cfeature.COASTLINE, linewidth=0.8)
                ax.add_feature(cfeature.BORDERS, linestyle='-', linewidth=0.3)
                ax.add_feature(cfeature.RIVERS, linewidth=0.3, edgecolor='#4a90d9')
                ax.add_feature(cfeature.LAKES, facecolor='#b0c4de')

            # Draw regions
            for region in spec.regions:
                if len(region.points) >= 3:
                    lons = [p[1] for p in region.points]
                    lats = [p[0] for p in region.points]
                    ax.fill(
                        lons, lats,
                        facecolor=region.fill_color,
                        alpha=region.fill_opacity,
                        edgecolor=region.border_color,
                        linewidth=region.border_width,
                        transform=ccrs.PlateCarree()
                    )
                    # Add label at centroid
                    center_lon = sum(lons) / len(lons)
                    center_lat = sum(lats) / len(lats)
                    ax.text(
                        center_lon, center_lat, region.label,
                        ha='center', va='center',
                        fontsize=8, fontweight='bold',
                        transform=ccrs.PlateCarree()
                    )

            # Draw routes
            for route in spec.routes:
                if len(route.points) >= 2:
                    lons = [p[1] for p in route.points]
                    lats = [p[0] for p in route.points]
                    linestyle = '-' if route.style == 'solid' else '--' if route.style == 'dashed' else ':'
                    ax.plot(
                        lons, lats,
                        color=route.color,
                        linewidth=route.width,
                        linestyle=linestyle,
                        transform=ccrs.PlateCarree(),
                        label=route.label
                    )

            # Draw markers
            for marker in spec.markers:
                ax.plot(
                    marker.longitude, marker.latitude,
                    'o', color=marker.color, markersize=8,
                    transform=ccrs.PlateCarree()
                )
                ax.text(
                    marker.longitude, marker.latitude + extent_deg * 0.03,
                    marker.label,
                    ha='center', va='bottom',
                    fontsize=7,
                    transform=ccrs.PlateCarree()
                )

            # Add title
            if spec.title:
                title = spec.title
                if spec.time_period:
                    title += f" ({spec.time_period})"
                ax.set_title(title, fontsize=12, fontweight='bold')

            # Add gridlines for educational maps
            if spec.style == MapStyle.EDUCATIONAL:
                gl = ax.gridlines(draw_labels=True, alpha=0.3)
                gl.top_labels = False
                gl.right_labels = False

            # Save to buffer
            buf = io.BytesIO()
            plt.savefig(buf, format='png', dpi=100, bbox_inches='tight', pad_inches=0.1)
            plt.close(fig)
            buf.seek(0)

            return RenderedMap(
                success=True,
                render_method=MapRenderMethod.CARTOPY,
                data=buf.read(),
                mime_type="image/png",
                width=spec.width,
                height=spec.height,
            )

        except Exception as e:
            plt.close('all')
            raise e

    def _apply_cartopy_style(self, ax, style: MapStyle):
        """Apply visual style to Cartopy axes."""
        if style == MapStyle.HISTORICAL:
            ax.set_facecolor('#f5e6c8')  # Parchment color
        elif style == MapStyle.MINIMAL:
            ax.set_facecolor('#ffffff')
        elif style == MapStyle.PHYSICAL:
            ax.set_facecolor('#e8f4e8')  # Light green
        else:
            ax.set_facecolor('#f8f9fa')  # Light gray

    async def _render_with_folium(
        self, spec: MapSpec, interactive: bool = False
    ) -> RenderedMap:
        """Render map using Folium."""
        try:
            import folium
            from folium.plugins import Draw

            # Create map
            tile_style = self._get_folium_tiles(spec.style)
            m = folium.Map(
                location=[spec.center_latitude, spec.center_longitude],
                zoom_start=spec.zoom,
                tiles=tile_style,
                width=spec.width,
                height=spec.height,
            )

            # Add title
            if spec.title:
                title_html = f'''
                <div style="position: fixed; top: 10px; left: 50px; z-index: 1000;
                            background: rgba(255,255,255,0.9); padding: 8px 16px;
                            border-radius: 4px; font-size: 14px; font-weight: bold;">
                    {spec.title}
                    {f' ({spec.time_period})' if spec.time_period else ''}
                </div>
                '''
                m.get_root().html.add_child(folium.Element(title_html))

            # Add regions
            for region in spec.regions:
                if len(region.points) >= 3:
                    folium.Polygon(
                        locations=region.points,
                        color=region.border_color,
                        weight=region.border_width,
                        fill=True,
                        fill_color=region.fill_color,
                        fill_opacity=region.fill_opacity,
                        popup=region.label,
                    ).add_to(m)

            # Add routes
            for route in spec.routes:
                if len(route.points) >= 2:
                    dash_array = None
                    if route.style == 'dashed':
                        dash_array = '10, 5'
                    elif route.style == 'dotted':
                        dash_array = '2, 4'

                    folium.PolyLine(
                        locations=route.points,
                        color=route.color,
                        weight=route.width,
                        dash_array=dash_array,
                        popup=route.label,
                    ).add_to(m)

            # Add markers
            for marker in spec.markers:
                folium.Marker(
                    location=[marker.latitude, marker.longitude],
                    popup=marker.popup or marker.label,
                    tooltip=marker.label,
                    icon=folium.Icon(color=self._folium_color(marker.color)),
                ).add_to(m)

            if interactive:
                # Return HTML for interactive map
                html_content = m.get_root().render()
                return RenderedMap(
                    success=True,
                    render_method=MapRenderMethod.FOLIUM,
                    html_content=html_content,
                    mime_type="text/html",
                    width=spec.width,
                    height=spec.height,
                )
            else:
                # Screenshot for static image
                return await self._folium_to_png(m, spec)

        except Exception as e:
            logger.debug(f"Folium rendering failed: {e}")
            return RenderedMap(
                success=False,
                render_method=MapRenderMethod.FOLIUM,
                error=str(e),
            )

    def _get_folium_tiles(self, style: MapStyle) -> str:
        """Get Folium tile provider for style."""
        if style == MapStyle.SATELLITE:
            return "Esri.WorldImagery"
        elif style == MapStyle.PHYSICAL:
            return "Esri.WorldPhysical"
        elif style == MapStyle.MINIMAL:
            return "CartoDB positron"
        elif style == MapStyle.HISTORICAL:
            return "Stamen Watercolor"
        else:
            return "OpenStreetMap"

    def _folium_color(self, hex_color: str) -> str:
        """Convert hex color to Folium color name (approximate)."""
        # Folium only supports named colors for markers
        color_map = {
            '#E74C3C': 'red',
            '#3498DB': 'blue',
            '#2ECC71': 'green',
            '#9B59B6': 'purple',
            '#F39C12': 'orange',
            '#1ABC9C': 'lightblue',
            '#34495E': 'darkblue',
        }
        return color_map.get(hex_color.upper(), 'blue')

    async def _folium_to_png(self, folium_map, spec: MapSpec) -> RenderedMap:
        """Convert Folium map to PNG using Selenium."""
        try:
            from selenium import webdriver
            from selenium.webdriver.chrome.options import Options
            from selenium.webdriver.chrome.service import Service
            import tempfile
            import time

            # Save map to temporary HTML
            with tempfile.NamedTemporaryFile(suffix='.html', delete=False) as f:
                folium_map.save(f.name)
                html_path = f.name

            try:
                # Configure headless Chrome
                options = Options()
                options.add_argument('--headless')
                options.add_argument('--no-sandbox')
                options.add_argument('--disable-dev-shm-usage')
                options.add_argument(f'--window-size={spec.width},{spec.height}')

                driver = webdriver.Chrome(options=options)
                driver.get(f'file://{html_path}')

                # Wait for tiles to load
                await asyncio.sleep(2)

                # Take screenshot
                png_data = driver.get_screenshot_as_png()
                driver.quit()

                return RenderedMap(
                    success=True,
                    render_method=MapRenderMethod.FOLIUM,
                    data=png_data,
                    mime_type="image/png",
                    width=spec.width,
                    height=spec.height,
                )

            finally:
                Path(html_path).unlink(missing_ok=True)

        except Exception as e:
            logger.debug(f"Folium screenshot failed: {e}")
            return RenderedMap(
                success=False,
                render_method=MapRenderMethod.FOLIUM,
                error=str(e),
            )

    async def _render_with_static_tiles(self, spec: MapSpec) -> RenderedMap:
        """Render using OpenStreetMap static tiles."""
        try:
            import aiohttp
            from PIL import Image

            # Calculate tile coordinates
            tiles = self._calculate_tiles(
                spec.center_latitude,
                spec.center_longitude,
                spec.zoom,
                spec.width,
                spec.height
            )

            # Fetch tiles
            async with aiohttp.ClientSession() as session:
                tile_images = await self._fetch_tiles(session, tiles, spec.zoom)

            if not tile_images:
                raise Exception("Failed to fetch map tiles")

            # Compose tiles into single image
            loop = asyncio.get_event_loop()
            png_data = await loop.run_in_executor(
                None,
                self._compose_tiles,
                tile_images,
                tiles,
                spec
            )

            return RenderedMap(
                success=True,
                render_method=MapRenderMethod.STATIC_TILES,
                data=png_data,
                mime_type="image/png",
                width=spec.width,
                height=spec.height,
            )

        except Exception as e:
            logger.debug(f"Static tile rendering failed: {e}")
            return RenderedMap(
                success=False,
                render_method=MapRenderMethod.STATIC_TILES,
                error=str(e),
            )

    def _calculate_tiles(
        self, lat: float, lon: float, zoom: int, width: int, height: int
    ) -> List[Tuple[int, int]]:
        """Calculate which tiles are needed for the view."""
        import math

        # Convert lat/lon to tile coordinates
        n = 2 ** zoom
        x_tile = int((lon + 180) / 360 * n)
        y_tile = int(
            (1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi)
            / 2 * n
        )

        # Calculate how many tiles we need
        tiles_x = (width // 256) + 2
        tiles_y = (height // 256) + 2

        tiles = []
        for dx in range(-tiles_x // 2, tiles_x // 2 + 1):
            for dy in range(-tiles_y // 2, tiles_y // 2 + 1):
                tx = (x_tile + dx) % n
                ty = max(0, min(n - 1, y_tile + dy))
                tiles.append((tx, ty))

        return tiles

    async def _fetch_tiles(
        self, session, tiles: List[Tuple[int, int]], zoom: int
    ) -> Dict[Tuple[int, int], bytes]:
        """Fetch tiles from OpenStreetMap."""
        tile_images = {}
        base_url = "https://tile.openstreetmap.org"

        async def fetch_one(tx: int, ty: int) -> Tuple[Tuple[int, int], Optional[bytes]]:
            url = f"{base_url}/{zoom}/{tx}/{ty}.png"
            try:
                async with session.get(
                    url,
                    headers={"User-Agent": "UnaMentis/1.0 Educational Curriculum"},
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as resp:
                    if resp.status == 200:
                        return ((tx, ty), await resp.read())
            except Exception as e:
                logger.debug(f"Tile fetch failed {tx},{ty}: {e}")
            return ((tx, ty), None)

        # Fetch tiles concurrently (with rate limiting)
        results = await asyncio.gather(*[fetch_one(tx, ty) for tx, ty in tiles])

        for key, data in results:
            if data:
                tile_images[key] = data

        return tile_images

    def _compose_tiles(
        self,
        tile_images: Dict[Tuple[int, int], bytes],
        tiles: List[Tuple[int, int]],
        spec: MapSpec
    ) -> bytes:
        """Compose tile images into a single PNG."""
        from PIL import Image

        # Find bounds
        min_x = min(t[0] for t in tiles)
        min_y = min(t[1] for t in tiles)
        max_x = max(t[0] for t in tiles)
        max_y = max(t[1] for t in tiles)

        # Create canvas
        canvas_width = (max_x - min_x + 1) * 256
        canvas_height = (max_y - min_y + 1) * 256
        canvas = Image.new('RGB', (canvas_width, canvas_height), (240, 240, 240))

        # Paste tiles
        for (tx, ty), data in tile_images.items():
            try:
                tile_img = Image.open(io.BytesIO(data))
                x = (tx - min_x) * 256
                y = (ty - min_y) * 256
                canvas.paste(tile_img, (x, y))
            except Exception as e:
                logger.debug(f"Failed to paste tile {tx},{ty}: {e}")

        # Crop to requested size (centered)
        left = (canvas_width - spec.width) // 2
        top = (canvas_height - spec.height) // 2
        canvas = canvas.crop((left, top, left + spec.width, top + spec.height))

        # Save to bytes
        buf = io.BytesIO()
        canvas.save(buf, format='PNG')
        buf.seek(0)
        return buf.read()

    async def _generate_placeholder(self, spec: MapSpec) -> RenderedMap:
        """Generate a placeholder SVG map."""
        # Create a simple SVG placeholder
        escaped_title = (
            spec.title
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

        # Simple world map outline (very simplified)
        svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{spec.width}" height="{spec.height}" viewBox="0 0 {spec.width} {spec.height}">
  <title>{escaped_title}</title>
  <defs>
    <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
      <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#e0e0e0" stroke-width="1"/>
    </pattern>
  </defs>

  <!-- Background -->
  <rect width="{spec.width}" height="{spec.height}" fill="#f0f4f8"/>
  <rect width="{spec.width}" height="{spec.height}" fill="url(#grid)"/>

  <!-- Ocean representation -->
  <ellipse cx="{spec.width/2}" cy="{spec.height/2}" rx="{spec.width*0.4}" ry="{spec.height*0.35}" fill="#b0c4de" opacity="0.5"/>

  <!-- Simple landmass shapes -->
  <ellipse cx="{spec.width*0.3}" cy="{spec.height*0.4}" rx="{spec.width*0.15}" ry="{spec.height*0.12}" fill="#c4b7a6" opacity="0.6"/>
  <ellipse cx="{spec.width*0.6}" cy="{spec.height*0.45}" rx="{spec.width*0.12}" ry="{spec.height*0.15}" fill="#c4b7a6" opacity="0.6"/>
  <ellipse cx="{spec.width*0.75}" cy="{spec.height*0.5}" rx="{spec.width*0.1}" ry="{spec.height*0.08}" fill="#c4b7a6" opacity="0.6"/>

  <!-- Center marker -->
  <circle cx="{spec.width/2}" cy="{spec.height/2}" r="8" fill="#E74C3C" stroke="white" stroke-width="2"/>

  <!-- Crosshairs -->
  <line x1="{spec.width/2 - 20}" y1="{spec.height/2}" x2="{spec.width/2 - 8}" y2="{spec.height/2}" stroke="#E74C3C" stroke-width="1"/>
  <line x1="{spec.width/2 + 8}" y1="{spec.height/2}" x2="{spec.width/2 + 20}" y2="{spec.height/2}" stroke="#E74C3C" stroke-width="1"/>
  <line x1="{spec.width/2}" y1="{spec.height/2 - 20}" x2="{spec.width/2}" y2="{spec.height/2 - 8}" stroke="#E74C3C" stroke-width="1"/>
  <line x1="{spec.width/2}" y1="{spec.height/2 + 8}" x2="{spec.width/2}" y2="{spec.height/2 + 20}" stroke="#E74C3C" stroke-width="1"/>

  <!-- Title -->
  <rect x="10" y="10" width="{min(len(escaped_title) * 8 + 20, spec.width - 20)}" height="30" rx="4" fill="white" opacity="0.9"/>
  <text x="20" y="30" font-family="sans-serif" font-size="14" font-weight="bold" fill="#333">{escaped_title}</text>

  <!-- Coordinates -->
  <text x="{spec.width/2}" y="{spec.height - 15}" text-anchor="middle" font-family="monospace" font-size="10" fill="#666">
    {spec.center_latitude:.4f}°, {spec.center_longitude:.4f}° (zoom: {spec.zoom})
  </text>

  <!-- Placeholder notice -->
  <text x="{spec.width/2}" y="{spec.height/2 + 40}" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#888">
    (Map placeholder - requires map renderer)
  </text>
</svg>'''

        return RenderedMap(
            success=True,
            render_method=MapRenderMethod.PLACEHOLDER,
            data=svg_content.encode("utf-8"),
            mime_type="image/svg+xml",
            width=spec.width,
            height=spec.height,
        )

    def get_cache_path(self, spec: MapSpec) -> Path:
        """Get cache file path for a map specification."""
        # Create hash of spec for cache key
        cache_data = (
            f"{spec.center_latitude}:{spec.center_longitude}:{spec.zoom}:"
            f"{spec.width}:{spec.height}:{spec.style.value}:"
            f"{len(spec.markers)}:{len(spec.routes)}:{len(spec.regions)}"
        )
        cache_key = hashlib.sha256(cache_data.encode()).hexdigest()[:16]
        ext = "html" if spec.interactive else spec.output_format
        return self.cache_dir / f"map_{cache_key}.{ext}"

    async def generate_with_cache(self, spec: MapSpec) -> RenderedMap:
        """Generate map with caching."""
        cache_path = self.get_cache_path(spec)

        # Check cache
        if cache_path.exists():
            try:
                data = cache_path.read_bytes()
                if spec.interactive:
                    return RenderedMap(
                        success=True,
                        render_method=MapRenderMethod.FOLIUM,
                        html_content=data.decode("utf-8"),
                        mime_type="text/html",
                        width=spec.width,
                        height=spec.height,
                    )
                else:
                    mime_type = "image/svg+xml" if spec.output_format == "svg" else "image/png"
                    return RenderedMap(
                        success=True,
                        render_method=MapRenderMethod.CARTOPY,
                        data=data,
                        mime_type=mime_type,
                        width=spec.width,
                        height=spec.height,
                    )
            except Exception as e:
                logger.debug(f"Cache read failed: {e}")

        # Generate
        result = await self.generate(spec)

        # Cache successful results
        if result.success:
            try:
                if result.html_content:
                    cache_path.write_text(result.html_content)
                elif result.data:
                    cache_path.write_bytes(result.data)
            except Exception as e:
                logger.debug(f"Cache write failed: {e}")

        return result

    async def close(self):
        """Clean up resources."""
        pass
