# Media API

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `http://localhost:8766`

---

## Overview

The Media API generates visual content including diagrams, mathematical formulas, and maps. These assets are used during tutoring sessions to enhance explanations.

---

## Capabilities

### GET /api/media/capabilities

Get available media generation capabilities.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "diagrams": {
    "enabled": true,
    "formats": ["mermaid", "graphviz", "plantuml"],
    "output_formats": ["svg", "png"]
  },
  "formulas": {
    "enabled": true,
    "format": "latex",
    "output_formats": ["svg", "png"]
  },
  "maps": {
    "enabled": true,
    "styles": ["standard", "satellite", "terrain"],
    "max_markers": 50
  }
}
```

---

## Diagram Generation

### Supported Diagram Types

| Type | Description | Example |
|------|-------------|---------|
| `mermaid` | Flowcharts, sequences, etc. | Mermaid syntax |
| `graphviz` | Graph layouts | DOT language |
| `plantuml` | UML diagrams | PlantUML syntax |

### POST /api/media/diagrams/validate

Validate diagram syntax without rendering.

**Request Body:**
```json
{
  "type": "mermaid",
  "source": "graph TD\n  A[Start] --> B[End]"
}
```

**Response (200 OK):**
```json
{
  "valid": true,
  "warnings": []
}
```

**Response (validation error):**
```json
{
  "valid": false,
  "errors": [
    {
      "line": 2,
      "message": "Unexpected token"
    }
  ]
}
```

---

### POST /api/media/diagrams/render

Render a diagram.

**Request Body:**
```json
{
  "type": "mermaid",
  "source": "graph TD\n  A[Newton's Laws] --> B[First Law]\n  A --> C[Second Law]\n  A --> D[Third Law]",
  "format": "svg",
  "options": {
    "theme": "default",
    "background": "transparent"
  }
}
```

**Response (200 OK):**
- Content-Type: `image/svg+xml` or `image/png`
- Body: Image data

**Alternative JSON Response (with `return_url=true`):**
```json
{
  "url": "/media/diagrams/abc123.svg",
  "width": 400,
  "height": 300,
  "cached": true
}
```

**Diagram Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `theme` | string | "default" | Color theme |
| `background` | string | "white" | Background color |
| `width` | integer | auto | Max width in pixels |
| `height` | integer | auto | Max height in pixels |
| `scale` | number | 1.0 | Scale factor |

---

## Formula Rendering

### POST /api/media/formulas/validate

Validate LaTeX formula syntax.

**Request Body:**
```json
{
  "latex": "F = ma"
}
```

**Response (200 OK):**
```json
{
  "valid": true,
  "warnings": []
}
```

---

### POST /api/media/formulas/render

Render a LaTeX formula.

**Request Body:**
```json
{
  "latex": "F = ma",
  "format": "svg",
  "options": {
    "display_mode": true,
    "font_size": 24,
    "color": "#000000"
  }
}
```

**Response (200 OK):**
- Content-Type: `image/svg+xml`
- Body: SVG data

**Formula Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `display_mode` | boolean | true | Display vs inline mode |
| `font_size` | integer | 20 | Font size in points |
| `color` | string | "#000000" | Text color |
| `background` | string | "transparent" | Background color |

**Example Formulas:**

```latex
# Newton's Second Law
F = ma

# Quadratic Formula
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}

# Einstein's Mass-Energy
E = mc^2

# Integral
\int_0^1 x^2 dx = \frac{1}{3}
```

---

## Map Generation

### GET /api/media/maps/styles

Get available map styles.

**Response (200 OK):**
```json
{
  "styles": [
    {
      "id": "standard",
      "name": "Standard",
      "description": "Default map style"
    },
    {
      "id": "satellite",
      "name": "Satellite",
      "description": "Satellite imagery"
    },
    {
      "id": "terrain",
      "name": "Terrain",
      "description": "Topographic view"
    },
    {
      "id": "dark",
      "name": "Dark",
      "description": "Dark mode map"
    }
  ]
}
```

---

### POST /api/media/maps/render

Render a map image.

**Request Body:**
```json
{
  "center": {
    "lat": 40.7128,
    "lng": -74.0060
  },
  "zoom": 12,
  "style": "standard",
  "size": {
    "width": 600,
    "height": 400
  },
  "markers": [
    {
      "lat": 40.7128,
      "lng": -74.0060,
      "label": "A",
      "color": "red"
    },
    {
      "lat": 40.7580,
      "lng": -73.9855,
      "label": "B",
      "color": "blue"
    }
  ],
  "overlays": [
    {
      "type": "polyline",
      "points": [
        {"lat": 40.7128, "lng": -74.0060},
        {"lat": 40.7580, "lng": -73.9855}
      ],
      "color": "#FF0000",
      "width": 3
    }
  ]
}
```

**Response (200 OK):**
- Content-Type: `image/png`
- Body: PNG image data

**Map Options:**

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `center` | object | yes | Center coordinates |
| `zoom` | integer | yes | Zoom level (1-20) |
| `style` | string | no | Map style ID |
| `size` | object | no | Image dimensions |
| `markers` | array | no | Marker locations |
| `overlays` | array | no | Lines, polygons |

**Marker Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `lat` | number | Latitude |
| `lng` | number | Longitude |
| `label` | string | Marker label (A-Z, 1-9) |
| `color` | string | Marker color |
| `icon` | string | Custom icon URL |

---

## Usage in Sessions

### Automatic Generation

During tutoring sessions, the AI can request media generation:

```json
{
  "type": "diagram",
  "instruction": "Create a force diagram showing Newton's third law",
  "context": "Discussing action-reaction pairs"
}
```

The server generates appropriate diagram code and renders it.

### Referenced Assets

Media can be pre-generated and referenced:

```json
{
  "asset_id": "media-001",
  "type": "formula",
  "latex": "F = ma",
  "url": "/media/formulas/media-001.svg"
}
```

---

## Caching

Media is cached based on content hash:

- Diagrams: Cached by source + options hash
- Formulas: Cached by LaTeX + options hash
- Maps: Cached by full request hash

Cache headers:
```
Cache-Control: public, max-age=86400
ETag: "abc123"
```

---

## Error Handling

### Validation Errors

```json
{
  "error": "Invalid LaTeX syntax",
  "code": "VALIDATION_ERROR",
  "details": {
    "position": 15,
    "message": "Unknown command \\foo"
  }
}
```

### Rendering Errors

```json
{
  "error": "Diagram too complex",
  "code": "RENDER_ERROR",
  "details": {
    "node_count": 150,
    "max_nodes": 100
  }
}
```

---

## Limits

| Resource | Limit |
|----------|-------|
| Diagram nodes | 100 |
| Formula length | 1000 chars |
| Map markers | 50 |
| Map size | 1920x1080 |
| Request rate | 60/minute |

---

## Related Documentation

- [Client Spec: Session Tab](../client-spec/02-SESSION_TAB.md) - Visual asset display
- [Curricula API](02-CURRICULA.md) - Asset management
